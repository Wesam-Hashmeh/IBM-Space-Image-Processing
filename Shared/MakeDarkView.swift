//
//  MakeDarkView.swift
//  MakeDarkView
//
//  Created by Jeff_Terry on 10/17/21.
//

import SwiftUI
import UniformTypeIdentifiers
import FITS
import FITSKit
import Accelerate


struct MakeDarkView: View {
    @EnvironmentObject var listOfDocuments: DocumentList
    
    @FocusedBinding(\.document) var document
    
    @State var dataFloat :DocumentBinding? = nil
    @State var dataWidth :UInt? = nil
    @State var dataHeight :UInt? = nil
    
    @State var selectingFilesToAdd: Bool = false
    
    @State var selectingFilesToSave: Bool = false
    
    @State var rawDataFromFITSFile : ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)?
    
    @State var imageHeight = 0
    @State var imageWidth = 0
    
    @State var darkFloatingArray :[Float] = []
    
    @State var darkDocument = FITSDocumentDocument(text: "Hello, world!")
    
    //    @State var deviationArray :[Float] = []
    //    @State var meanArray :[Float] = []
    //    @State var pointArray :[Float] = []
    
    let numberOfStandardDeviationsAway = 1.5
    
    /* This may not be the best way to do this. May be better to load in the image multiple times rather than try to store in memory */
    // @State var dataFromAllTheImagesToCombine :[[Float]] = []
    
    @State var selectedImage = ""
    
    @State var imageArray :[URL] = []
    
    @State var darkImage :CGImage?
    
    var body: some View {
        
        VStack{
            
            Spacer()
            
            
            Button("Pick") {
                imageArray.removeAll()
                darkFloatingArray.removeAll()
                selectingFilesToAdd.toggle()
            }
            .fileImporter(
                isPresented: $selectingFilesToAdd,
                allowedContentTypes: [.fitDocument],
                allowsMultipleSelection: true,
                onCompletion: { result in
                    print("Picked: \(result)")
                    
                    let fileUrlsToAdd = try? result.get()
                    
                    imageArray.append(contentsOf: fileUrlsToAdd!)
                    
                    print(imageArray)
                })
            
            Spacer()
            
            Button("Merge Dark Files"){
                
                loadAndSum()
                
            }
            
            Button("Save"){
                
                saveFile()
                selectingFilesToSave = true
                
            }
            .fileExporter(isPresented: $selectingFilesToSave, document: darkDocument, contentType: .fitDocument, defaultFilename: "Dark", onCompletion: { result in
                print("Picked: \(result)")
                
                //                let fileUrlsToAdd = try? result.get()
                //
                //                imageArray.append(contentsOf: fileUrlsToAdd!)
                //
                //                print(imageArray)
            })
            
            
            
            
            VStack{
                //rawImage?.resizable().scaledToFit()
                if (darkImage != nil){
                    Image((darkImage!), scale: 2.0, label: Text("Raw")).resizable().scaledToFit()
                }
            }
            
            
            
            
        }
        
    }
    
    func saveFile(){
        
        let floatData :[FITSByte_F] = darkDocument.rawFloatData.bigEndian
        
        darkDocument.myPrimaryHDU = PrimaryHDU(width: imageWidth, height: imageHeight, vectors: floatData)
        
        
        print(darkDocument.myPrimaryHDU)
    }
    
    func loadAndSum(){
        
        imageHeight = 0
        imageWidth = 0
        
        //       dataFromAllTheImagesToCombine.removeAll()
        //        deviationArray.removeAll()
        //        meanArray.removeAll()
        
        var deviation :[Float] = []
        var mean :[Float] = []
        var pointArray :[Float] = []
        var dataFromAllTheImagesToCombine :[[Float]] = []
        
        for item in imageArray
        {
            autoreleasepool{
                
                let selectedFile: URL = item
                
                print("Selected file is", selectedFile)
                
                //trying to get access to url contents
                if (CFURLStartAccessingSecurityScopedResource(selectedFile as CFURL)) {
                    
                    
                    guard let read_data = try! FitsFile.read(contentsOf: selectedFile) else { return }
                    let prime = read_data.prime
                    print(prime)
                    prime.v_complete(onError: {_ in
                        print("CGImage creation error")
                    }) { result in
                        
                        rawDataFromFITSFile = result
                        
                        let floatDataFromFITSFile :[Float] = self.extractFloatData(Data: rawDataFromFITSFile!)
                        
                        //Buffer from FITS File
                        let buffer = rawDataFromFITSFile!.1
                        //destination buffer
                        
                        if ((imageWidth == 0) && (imageHeight == 0)){
                            
                            imageWidth = Int(buffer.width)
                            imageHeight = Int(buffer.height)
                            
                        }
                        else if (imageWidth != Int(buffer.width)) || (imageHeight != Int(buffer.height)){
                            
                            print("Image sizes do not match.")
                            return
                        }
                        
                        dataFromAllTheImagesToCombine.append(floatDataFromFITSFile)
                        
                        
                        
                    }
                    
                    
                    //done accessing the url
                    CFURLStopAccessingSecurityScopedResource(selectedFile as CFURL)
                    
                    
                }
                else {
                    print("Permission error!")
                }
            }
        }
        
        // Calculate Standard Deviation and Mean
        
        for pixel in stride(from: 0, to: imageHeight*imageWidth, by: 1){
            
            pointArray.removeAll()
            
            for floatingArray in dataFromAllTheImagesToCombine {
                
                pointArray.append(floatingArray[pixel])
                
                
            }
            
            
            mean.append(pointArray.mean)
            deviation.append(pointArray.stdev ?? 0.0)
            
            
        }
        
        
        // Sum if the pixel is within numberOfStandardDeviationsAway from the mean
        
        var darkFloatArray :[Float] = Array(repeating: 0.0, count: imageHeight*imageWidth)
        
        for pixel in stride(from: 0, to: imageHeight*imageWidth, by: 1){
            
            var sumCounter = 0
            
            for floatingArray in dataFromAllTheImagesToCombine {
                
                if (abs(floatingArray[pixel]-mean[pixel]) <= Float(numberOfStandardDeviationsAway)*deviation[pixel] ){
                    
                    sumCounter += 1
                    
                    darkFloatArray[pixel] = (darkFloatArray[pixel]*Float(sumCounter - 1) + floatingArray[pixel])/Float(sumCounter)
                    
                    
                    
                    
                }
                
                
            }
            
            //            print(darkFloatArray[pixel], sumCounter )
            //darkFloatArray[pixel] *= 10
            
        }
        
        
        
        darkDocument.imageHeight = UInt(imageHeight)
        darkDocument.imageWidth = UInt(imageWidth)
        
        darkDocument.rawFloatData = []
        darkDocument.rawFloatData.append(contentsOf: darkFloatArray)
        
                    print("darkDocument darkFloatArray", darkDocument.rawFloatData[10133], darkDocument.imageWidth, darkDocument.imageHeight)
        
        let rowBytes :Int = Int(darkDocument.imageWidth) * MemoryLayout<Float>.size
        
        let starImage = returningCGImage(data: darkDocument.rawFloatData, width: Int(darkDocument.imageWidth), height: Int(darkDocument.imageHeight), rowBytes: rowBytes)
        
        
        darkDocument.starImage = starImage
        
        darkDocument.exportStarImage()
        
        darkImage = darkDocument.starImage
        
        
    }
    
    func extractFloatData(Data: ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)) -> ([Float]) {
        
        
        let floatData = returnRawFloat(RawData: Data)
        
        return floatData
    }
    
    
    
    func PopulateImageField(){
        
        imageArray.removeAll()
        
        //  imageArray.append(contentsOf: listOfDocuments.documentName)
        
        let starDocument = listOfDocuments.documentList[0]
        
        print(starDocument.imageHeight)
        
        let imageHeight = starDocument.imageHeight.wrappedValue
        
        print(imageHeight)
        
        print("Finding Stars")
        print(document)
        
    }
    
}

struct MakeDarkView_Previews: PreviewProvider {
    static var previews: some View {
        MakeDarkView()
    }
}
