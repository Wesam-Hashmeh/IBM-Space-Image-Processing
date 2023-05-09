//
//  AlignImages.swift
//  AlignIMages
//
//  Created by Jeff_Terry on 11/18/21.
//

import Foundation
import SwiftUI
import Accelerate
import Accelerate.vImage
import simd
import FITS
import FITSKit

struct AlignImages: View {
    
    @EnvironmentObject var listOfDocuments: DocumentList
    
    @FocusedBinding(\.document) var document
    
    @State var dataFloat :DocumentBinding? = nil
    @State var dataWidth :UInt? = nil
    @State var dataHeight :UInt? = nil
    
    
    @State var primaryImage :CGImage?
    @State var alignedImage :CGImage?
    @State var extractData = ExtractDataClass()
    @State var starLocator = StarCoordinateLocator()
    
    @State var alignedDocument = FITSDocumentDocument(text: "Hello, world!")
    @State var selectingFilesToSave: Bool = false
    
    @State var imageArray :[URL] = []
    @State var selectingFilesToAlign: Bool = false
    @State var selectingPrimaryImage: Bool = false
    
    @State var selectedPrimaryImage :URL? = nil
    @State var selectedAlignmentImage = ""
    
    
    var body: some View {
        
        VStack{
            
            Button("Select the Primary Image") {
                
                selectingPrimaryImage.toggle()
            }
            .fileImporter(
                isPresented: $selectingPrimaryImage,
                allowedContentTypes: [.fitDocument],
                allowsMultipleSelection: false,
                onCompletion: { result in
                    print("Picked: \(result)")
                    
                    let fileUrlsToAdd = try? result.get()
                    
                    selectedPrimaryImage = fileUrlsToAdd![0]
                    
                })
            
            
            Button("Select the Image(s) To Be Aligned") {
                imageArray.removeAll()
                selectingFilesToAlign.toggle()
            }
            .fileImporter(
                isPresented: $selectingFilesToAlign,
                allowedContentTypes: [.fitDocument],
                allowsMultipleSelection: true,
                onCompletion: { result in
                    print("Picked: \(result)")
                    
                    let fileUrlsToAdd = try? result.get()
                    
                    imageArray.append(contentsOf: fileUrlsToAdd!)
                    
                    print(imageArray)
                })
            
            
            Button(action: {alignTheImages(nameOfPrimaryDocument: selectedPrimaryImage!, nameOfAlignmentImages: imageArray)}, label: {
                Text("Align the Images")
            })
            
            Spacer()
            
        }
        
        
        
        VStack{
            if (primaryImage != nil){
                Image((primaryImage!), scale: 2.0, label: Text("Raw")).resizable().scaledToFit()
            }
        }
        
        VStack{
            if (alignedImage != nil){
                Image((alignedImage!), scale: 2.0, label: Text("Raw")).resizable().scaledToFit()
            }
        }
    }
    
    /// Function assigns a url to the chosen image, reads the raw data from the image, chops image up into rows and attempts to find possible stars within those rows. It then makes trianges between possible stars within each of the images, and uses the trianges to align the chosen images,
    /// - Parameters:
    ///   - nameOfPrimaryDocument: The selected .fits file is labeled this.
    ///   - nameOfAlignmentImages: <#nameOfAlignmentImages description#>
    func alignTheImages(nameOfPrimaryDocument: URL, nameOfAlignmentImages:[URL]) {
        print(nameOfPrimaryDocument)
        
        
        let selectedFile: URL = nameOfPrimaryDocument
        
        print("Selected file is", selectedFile)
        
        var primaryImageData :[Float] = []
        var rawDataFromPrimaryFITSFile : ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)?
        var imageWidth = 0
        var imageHeight = 0

        //trying to get access to url contents
        if (CFURLStartAccessingSecurityScopedResource(selectedFile as CFURL)) {
            
            
            guard let read_data = try! FitsFile.read(contentsOf: selectedFile) else { return }
            let prime = read_data.prime
            print(prime)
            prime.v_complete(onError: {_ in
                print("CGImage creation error")
            }) { result in
                
                rawDataFromPrimaryFITSFile = result
                
                primaryImageData = extractData.extractFloatData(Data: rawDataFromPrimaryFITSFile!)
                
                //Buffer from FITS File
                let buffer = rawDataFromPrimaryFITSFile!.1
                //destination buffer
                
                imageWidth = Int(buffer.width)
                imageHeight = Int(buffer.height)

            }

            //done accessing the url
            CFURLStopAccessingSecurityScopedResource(selectedFile as CFURL)

        }
        else {
            print("Permission error!")
        }

        dataWidth =  UInt(imageWidth)
        
        dataHeight = UInt(imageHeight)
        
        
        //Get the floating point array of image values from the selected Document
        
        let sourceRowBytes :Int = Int(dataWidth!) * MemoryLayout<Float>.size
        
        let relativePeakLimit = primaryImageData.max()!*0.20
        
        
        var centroidCoordinatesOfPossibleStarsInPrimaryImage :[xy_coord] = []
        
        let myStarCoordinateLocator = StarCoordinateLocator()
        
        //finds the coordiantes of possible stars in the image.
        centroidCoordinatesOfPossibleStarsInPrimaryImage = myStarCoordinateLocator.findTheStars(imageData: primaryImageData, width: Int(dataWidth!), height: Int(dataHeight!), relativePeakLimit: relativePeakLimit)
        
        let simdVectorsInPrimaryImage = starLocator.convertCoordinatesTosimdForTriangleSearch(coordinates: centroidCoordinatesOfPossibleStarsInPrimaryImage)
        
        
        let luminanceArray = imageArray.filter {
            
            word in return word.lastPathComponent.contains("Luminance")
            
        }

        let centroidCoordinatesOfPossibleStarsInPrimaryImageDummy = centroidCoordinatesOfPossibleStarsInPrimaryImage
        let rawDataFromPrimaryFITSFileDummy: ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)? = rawDataFromPrimaryFITSFile
        let imageWidthLocal = imageWidth
        let imageHeightLocal = imageHeight
        let relativePeakLimitDummy = relativePeakLimit
        
        let dataWidthLocal =  UInt(imageWidth)
        
        let dataHeightLocal = UInt(imageHeight)
        
        Task{
            let _ = await withTaskGroup(of: Void.self){ taskGroup in
            imageLoop: for item in luminanceArray{
                taskGroup.addTask{
                    var imageWidthDummy = imageWidthLocal
                    var imageHeightDummy = imageHeightLocal
                    var relativePeakLimitLocal = relativePeakLimitDummy
                    let centroidCoordinatesOfPossibleStarsInPrimaryImageLocal = centroidCoordinatesOfPossibleStarsInPrimaryImageDummy
                    let myStarCoordinateLocator = StarCoordinateLocator()
                    
                    let extractData2 = ExtractDataClass()
                    var alignedOutput :[Float] = await Array(repeating: Float(0.0), count: Int(dataWidth!*dataHeight!))
                    
                    let isTheImageGoodDummy = false
                    //is this a dummy variable? what is its purpose? -DB
                    
                    autoreleasepool{
                        var processingFailed = false
                        var isTheImageGoodlocal = isTheImageGoodDummy
                        
                        var rawDataFromAlignmentFITSFile : ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)?
                        
                        
                        print("Selected file is", item)
                        
                        
                        //Get the floating point array of luminance values from the alignment Document
                        var alignmentImageData :[Float] = []
                        
                        //trying to get access to url contents
                        if (CFURLStartAccessingSecurityScopedResource(selectedFile as CFURL)) {
                            
                            
                            guard let read_data = try! FitsFile.read(contentsOf: item) else { return }
                            let prime = read_data.prime
                            print(prime)
                            prime.v_complete(onError: {_ in
                                print("CGImage creation error")
                            }) { result in
                                
                                rawDataFromAlignmentFITSFile = result
                                
                                alignmentImageData = extractData2.extractFloatData(Data: rawDataFromAlignmentFITSFile!)
                                
                                //Buffer from FITS File
                                let buffer = rawDataFromPrimaryFITSFileDummy!.1
                                //destination buffer
                                
                                imageWidthDummy = Int(buffer.width)
                                imageHeightDummy = Int(buffer.height)
                                
                            }

                            //done accessing the url
                            CFURLStopAccessingSecurityScopedResource(selectedFile as CFURL)
                            
                            
                        }
                        else {
                            print("Permission error!")
                        }
                        
                        
                        var deltaX = Float(0.0)
                        var deltaY = Float(0.0)
                        var angle = Float(0.0)
                        
                        
                        if item != selectedFile{
                            
                            //let sourceRowBytes :Int = Int(dataWidth!) * MemoryLayout<Float>.size
                            
                            relativePeakLimitLocal = alignmentImageData.max()!*0.20
                            
                            var centroidCoordinatesOfPossibleStarsInAlignmentImage :[xy_coord] = []
                            
                            centroidCoordinatesOfPossibleStarsInAlignmentImage = myStarCoordinateLocator.findTheStars(imageData: alignmentImageData, width: Int(dataWidthLocal), height: Int(dataHeightLocal), relativePeakLimit: relativePeakLimitLocal)
                            
                            print(nameOfPrimaryDocument)
                            print(centroidCoordinatesOfPossibleStarsInPrimaryImageLocal)
                            //      print(nameOfAlignmentImage)
                            print(centroidCoordinatesOfPossibleStarsInAlignmentImage)
                            
                            
                            
                            
                            let simdVectorsInAlignmentImage = myStarCoordinateLocator.convertCoordinatesTosimdForTriangleSearch(coordinates: centroidCoordinatesOfPossibleStarsInAlignmentImage)
                            
                            
                            //At this point the centroids have been identified
                            //Now to generate the centroid triangles
                            let trianglesInPrimaryImage = myStarCoordinateLocator.findTrianglesInImage(points: simdVectorsInPrimaryImage)
                            
                            let trianglesInAlignmentImage = myStarCoordinateLocator.findTrianglesInImage(points: simdVectorsInAlignmentImage)
                            
                            let matchingTriangles = myStarCoordinateLocator.findMatchingTriangles(primary: trianglesInPrimaryImage, alignment: trianglesInAlignmentImage)
                            
                            if matchingTriangles.count == 0{
                                
                                // continue imageLoop
                                processingFailed = true
                            }
                            
                            var wellAlignedTriangles : aligntrianglereturn = []
                            if !processingFailed{
                                wellAlignedTriangles = myStarCoordinateLocator.alignTriangles(matchedTriangles: matchingTriangles)
                                
                                if wellAlignedTriangles.count == 0{
                                    
                                    //continue imageLoop
                                    processingFailed = true
                                }
                            }
                            
                            var matchedPoints : matchtrianglereturn = []
                            if !processingFailed{
                                matchedPoints = myStarCoordinateLocator.findMatchingPoints(matchedTriangles: wellAlignedTriangles)
                                
                                if matchedPoints.count == 0{
                                    
                                    processingFailed = true
                                    //continue
                                    
                                }
                            }
                            if !processingFailed{
                                isTheImageGoodlocal = true}
                            
                            if isTheImageGoodlocal{
                                let alignmentParameters = myStarCoordinateLocator.findAngleAndDeltas(matchingPointsArray: matchedPoints, imageSize: (width: imageWidthDummy, height: imageHeightDummy) )
                                
                                if alignmentParameters.failed {
                                    isTheImageGoodlocal  = false
                                }
                                deltaX = alignmentParameters.deltaX
                                deltaY = alignmentParameters.deltaY
                                angle = alignmentParameters.angle
                                
                            }
                            
                            
                        }
                        else{
                            
                            isTheImageGoodlocal = true
                        }
                        
                        
                        if isTheImageGoodlocal {
                            
                            
                            myStarCoordinateLocator.alignedImage = myStarCoordinateLocator.rotateAndTranslateImage(&alignmentImageData, &alignedOutput, sourceRowBytes, deltaX: deltaX, deltaY: deltaY, angle: angle, dataHeight: dataHeightLocal, dataWidth: dataWidthLocal)
                            
                            
                            let floatData :[FITSByte_F] = alignedOutput.bigEndian
                            
                            let myPrimaryHDU = PrimaryHDU(width: imageWidthDummy, height: imageHeightDummy, vectors: floatData)
                            
                            let file = FitsFile(prime: myPrimaryHDU)
                            
                            let filePath = URL(fileURLWithPath: NSHomeDirectory())
                            
                            let newFileURLString = filePath.absoluteString + "/Pictures/Align" + item.lastPathComponent
                            
                            let url = URL(string: newFileURLString)
                            print(url)
                            
                            file.write(to: url!, onError: { error in
                                print(error)
                            }) {
                                // file written
                                
                                print("File written")
                            }
                        }
                    }
                }
            }
            }
        }
    }

    func extractFloatData(Data: ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)) -> ([Float]) {
        
        let floatData = returnRawFloat(RawData: Data)
        
        return floatData
    }
}
