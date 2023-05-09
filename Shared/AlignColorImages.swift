//
//  AlignColorImages.swift
//  AlignColorImages
//
//  Created by Jeff_Terry on 12/3/21.
//

import Foundation
import SwiftUI
import Accelerate
import Accelerate.vImage
import simd
import FITS
import FITSKit

typealias aligntrianglereturn = [(primary: (pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float), alignment: (pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float))]

typealias matchtrianglereturn = [(primary: simd_float3,  alignment: simd_float3)]

struct AlignColorImages: View {
    
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
    
    /// Based on the width of images, splits the image into rows, finds the brightest spots in those rows, tags them as "luminous," and uses them as anchors to align the images together. Creates triangles between all of the centroid peaks, creating a mesh, with the stars at the vertices. Splits image up into RGB arrays, Aligns the image using this method. Seems like it could be significantly cut down, as it is a copy-paste job of the same function from AlignImages, though with the RGB filters.
    /// - Parameters:
    ///   - nameOfPrimaryDocument: <#nameOfPrimaryDocument description#>
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
        
        centroidCoordinatesOfPossibleStarsInPrimaryImage = myStarCoordinateLocator.findTheStars(imageData: primaryImageData, width: Int(dataWidth!), height: Int(dataHeight!), relativePeakLimit: relativePeakLimit)
        
        let simdVectorsInPrimaryImage = starLocator.convertCoordinatesTosimdForTriangleSearch(coordinates: centroidCoordinatesOfPossibleStarsInPrimaryImage)
        
        let luminanceArray = nameOfAlignmentImages.filter {
            
            word in return word.lastPathComponent.contains("Luminance")
    
        }
        
        let redArray = nameOfAlignmentImages.filter {
            
            word in return word.lastPathComponent.contains("Red")
    
        }
        
        let greenArray = nameOfAlignmentImages.filter {
            
            word in return word.lastPathComponent.contains("Green")
    
        }
        
        let blueArray = nameOfAlignmentImages.filter {
            
            word in return word.lastPathComponent.contains("Blue")
    
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
        let luminanceLastPathComponent = item.lastPathComponent
        var alignedOutput :[Float] = await Array(repeating: Float(0.0), count: Int(dataWidth!*dataHeight!))

        let testPathComponent = luminanceLastPathComponent.replacingOccurrences(of: "flatCorrectedLuminance", with: "", options: String.CompareOptions.literal, range: nil)
        
        let redFilenameArray = redArray.filter{
            
            word in return word.lastPathComponent.contains(testPathComponent)
        }
        
        let greenFilenameArray = greenArray.filter{
            
            word in return word.lastPathComponent.contains(testPathComponent)
        }
        
        let blueFilenameArray = blueArray.filter{
            
            word in return word.lastPathComponent.contains(testPathComponent)
        }
        var isTheImageGoodDummy = false
    if ((redFilenameArray.count != 1) || (blueFilenameArray.count != 1) || (greenFilenameArray.count != 1) ) {
            
            print("There is a color file missing")
            isTheImageGoodDummy = true
        }
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
                 
                 relativePeakLimitLocal = alignmentImageData.max()!*0.20
                
                var centroidCoordinatesOfPossibleStarsInAlignmentImage :[xy_coord] = []
                
                centroidCoordinatesOfPossibleStarsInAlignmentImage = myStarCoordinateLocator.findTheStars(imageData: alignmentImageData, width: Int(dataWidthLocal), height: Int(dataHeightLocal), relativePeakLimit: relativePeakLimitLocal)
                
                print(nameOfPrimaryDocument)
                print(centroidCoordinatesOfPossibleStarsInPrimaryImageLocal)
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
                
   
                var floatData :[FITSByte_F] = alignedOutput.bigEndian

                var myPrimaryHDU = PrimaryHDU(width: imageWidthDummy, height: imageHeightDummy, vectors: floatData)

                var file = FitsFile(prime: myPrimaryHDU)

                var filePath = URL(fileURLWithPath: NSHomeDirectory())

                var newFileURLString = filePath.absoluteString + "/Pictures/Align" + item.lastPathComponent

                var url = URL(string: newFileURLString)
                print(url)

                file.write(to: url!, onError: { error in
                    print(error)
                }) {
                    // file written

                    print("File written")
                }

                //Get the floating point array of red values from the alignment Document
                alignmentImageData = []
                
                //trying to get access to url contents
                if (CFURLStartAccessingSecurityScopedResource(selectedFile as CFURL)) {
                    
                    guard let read_data = try! FitsFile.read(contentsOf: redFilenameArray[0]) else { return }
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
                
                myStarCoordinateLocator.alignedImage = myStarCoordinateLocator.rotateAndTranslateImage(&alignmentImageData, &alignedOutput, sourceRowBytes, deltaX: deltaX, deltaY: deltaY, angle: angle, dataHeight: dataHeightLocal, dataWidth: dataWidthLocal)
                
                
                //Write aligned red data
                floatData = alignedOutput.bigEndian

                myPrimaryHDU = PrimaryHDU(width: imageWidthDummy, height: imageHeightDummy, vectors: floatData)

                file = FitsFile(prime: myPrimaryHDU)

                filePath = URL(fileURLWithPath: NSHomeDirectory())

                newFileURLString = filePath.absoluteString + "/Pictures/Align" + redFilenameArray[0].lastPathComponent

                url = URL(string: newFileURLString)
                print(url)

                file.write(to: url!, onError: { error in
                    print(error)
                }) {
                    // file written

                    print("File written")
                }
            
                //Get the floating point array of green values from the alignment Document
                alignmentImageData = []
                
                //trying to get access to url contents
                if (CFURLStartAccessingSecurityScopedResource(selectedFile as CFURL)) {
                                        
                    
                    guard let read_data = try! FitsFile.read(contentsOf: greenFilenameArray[0]) else { return }
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
                
                myStarCoordinateLocator.alignedImage = myStarCoordinateLocator.rotateAndTranslateImage(&alignmentImageData, &alignedOutput, sourceRowBytes, deltaX: deltaX, deltaY: deltaY, angle: angle, dataHeight: dataHeightLocal, dataWidth: dataWidthLocal)
                
                
                //Write aligned green data
                floatData = alignedOutput.bigEndian

                myPrimaryHDU = PrimaryHDU(width: imageWidthDummy, height: imageHeightDummy, vectors: floatData)

                file = FitsFile(prime: myPrimaryHDU)

                filePath = URL(fileURLWithPath: NSHomeDirectory())

                newFileURLString = filePath.absoluteString + "/Pictures/Align" + greenFilenameArray[0].lastPathComponent

                url = URL(string: newFileURLString)
                print(url)

                file.write(to: url!, onError: { error in
                    print(error)
                }) {
                    // file written

                    print("File written")
                }

                //Get the floating point array of blue values from the alignment Document
                alignmentImageData = []
                
                //trying to get access to url contents
                if (CFURLStartAccessingSecurityScopedResource(selectedFile as CFURL)) {
                                        
                    
                    guard let read_data = try! FitsFile.read(contentsOf: blueFilenameArray[0]) else { return }
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
                
                myStarCoordinateLocator.alignedImage = myStarCoordinateLocator.rotateAndTranslateImage(&alignmentImageData, &alignedOutput, sourceRowBytes, deltaX: deltaX, deltaY: deltaY, angle: angle, dataHeight: dataHeightLocal, dataWidth: dataWidthLocal)
                
                
                //Write aligned blue data
                floatData = alignedOutput.bigEndian

                myPrimaryHDU = PrimaryHDU(width: imageWidthDummy, height: imageHeightDummy, vectors: floatData)

                file = FitsFile(prime: myPrimaryHDU)

                filePath = URL(fileURLWithPath: NSHomeDirectory())

                newFileURLString = filePath.absoluteString + "/Pictures/Align" + blueFilenameArray[0].lastPathComponent

                url = URL(string: newFileURLString)
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
