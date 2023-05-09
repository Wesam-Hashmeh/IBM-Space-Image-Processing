//
//  SubtractDarkView.swift
//  SubtractDarkView
//
//  Created by Jeff_Terry on 11/3/21.
//

import SwiftUI
import UniformTypeIdentifiers
import FITS
import FITSKit
import Accelerate

struct SubtractDarkView: View {
    
    
    // threading with the Task
    @EnvironmentObject var listOfDocuments: DocumentList
    
    @FocusedBinding(\.document) var document
    
    @State var dataFloat :DocumentBinding? = nil
    @State var dataWidth :UInt? = nil
    @State var dataHeight :UInt? = nil
    
    @State var selectingDarkFile: Bool = false
    @State var selectingFilesToAdd: Bool = false
    
    @State var selectingFilesToSave: Bool = false
    
    @State var rawDataFromFITSFile : ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)?
    
    @State var imageHeight = 0
    @State var imageWidth = 0
    
    @State var darkFloatArray: [Float] = []
    
    @State var darkDocument = FITSDocumentDocument(text: "Hello, world!")
    
    @State var allowMultipleDirectories = false
    @State var showingAlert = false
    
//    @State var deviationArray :[Float] = []
//    @State var meanArray :[Float] = []
//    @State var pointArray :[Float] = []
    
    let numberOfStandardDeviationsAway = 1.5
    
    /* This may not be the best way to do this. May be better to load in the image multiple times rather than try to store in memory */
    /*Keeping the image in memory obviously increases memory usage, but loading it multiple times would present a bottleneck on the program considering the I/O speeds of most computers. It's best to reduce the number of images dealt with at once in order to reduce the memory usage*/
    /*We only need to deal with one image at a time, so the images should be loaded as they are used*/
    
    
   // @State var dataFromAllTheImagesToCombine :[[Float]] = []
    
    @State var selectedImage = ""
    
    @State var imageArray :[URL] = []
    
    @State var darkImage :CGImage?
    
    var body: some View {
        
        VStack{
            
            Spacer()
            
            Button("Select Dark") {
                
                
                darkFloatArray.removeAll()
                selectingDarkFile.toggle()
                
                    }
                .fileImporter(
                        isPresented: $selectingDarkFile,
                        allowedContentTypes: [.fitDocument],
                        allowsMultipleSelection: false,
                        onCompletion: { result in
                            print("Picked: \(result)")
                            
                            let darkFileURL = try? result.get()

                            loadDarkImage(darkFileURL:  darkFileURL![0])
                        })
            Spacer()
            
            HStack{
                
                
                
                Button("Select Files To Process") {
                    if (!allowMultipleDirectories){
                        
                        imageArray.removeAll()
                        
                    }
                    selectingFilesToAdd.toggle()
                        }
                    .fileImporter(
                            isPresented: $selectingFilesToAdd,
                            allowedContentTypes: [.fitDocument],
                            allowsMultipleSelection: true,
                            onCompletion: { result in
                                print("Picked: \(result)")
                                
                                let imageFileURL = try? result.get()

                                imageArray.append(contentsOf: imageFileURL!)

                                print(imageArray)
                            })
                
                
                
                Button(action: toggleAllowMultipleDirectories){
                    

                            HStack{
                                Image(systemName: allowMultipleDirectories ? "checkmark.square": "square")
                                Text("Allow Selection Of Multiple Directories")
                            }

                        }
                        .alert(isPresented: $showingAlert) {
                            Alert(title: Text("Warning"), message: Text("If You Allow Selection Of Multiple Directories, You Are Responsible For Clearing The File Paths As Needed"), dismissButton: .default(Text("Got it!")))
                        }
                
                if (allowMultipleDirectories == true){
                    
                    Button("Clear File Paths"){
                        clearFilePaths()
                    }
                    
                }
                    
                

                
                
            }
            
            
            
            Spacer()
            
            Button("Apply Dark To Files"){
                
                print(imageArray)
                
                loadAndSubtractDark()
                
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
            
            Spacer()
            
            
        }
            
            VStack{
                //rawImage?.resizable().scaledToFit()
                if (darkImage != nil){
                    Image((darkImage!), scale: 2.0, label: Text("Raw")).resizable().scaledToFit()
                }
            }

            
        
        
        
                
    }
    
    func clearFilePaths(){
        
        imageArray = []
    }
    
    func toggleAllowMultipleDirectories()
    {
        allowMultipleDirectories = !allowMultipleDirectories
        showingAlert = !showingAlert
        
    }

    func saveFile(){
        
        let floatData :[FITSByte_F] = darkDocument.rawFloatData.bigEndian

        darkDocument.myPrimaryHDU = PrimaryHDU(width: imageWidth, height: imageHeight, vectors: floatData)
        
        
        print(darkDocument.myPrimaryHDU)
    }
    
    func loadDarkImage(darkFileURL: URL){
        
        imageHeight = 0
        imageWidth = 0
        
        let selectedFile: URL = darkFileURL
                        
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
                                
                darkFloatArray.append(contentsOf: floatDataFromFITSFile)
                                
                }
                            
                                
                //done accessing the url
                CFURLStopAccessingSecurityScopedResource(selectedFile as CFURL)
                            
                            
                }
                else {
                    print("Permission error!")
                }
        

        
        darkDocument.imageHeight = UInt(imageHeight)
        darkDocument.imageWidth = UInt(imageWidth)
        
        darkDocument.rawFloatData = []
        darkDocument.rawFloatData.append(contentsOf: vDSP.multiply(10.0, darkFloatArray))
        
//            print("newDocument darkFloatArray", newDocument.rawFloatData[33], newDocument.imageWidth, newDocument.imageHeight)
        
        let rowBytes :Int = Int(darkDocument.imageWidth) * MemoryLayout<Float>.size
        
        let starImage = returningCGImage(data: darkDocument.rawFloatData, width: Int(darkDocument.imageWidth), height: Int(darkDocument.imageHeight), rowBytes: rowBytes)
        
        
        darkDocument.starImage = starImage
        
        darkDocument.exportStarImage()
        
        darkImage = darkDocument.starImage
        
        
    }
    
    func loadAndSubtractDark() {
        
        imageHeight = 0
        imageWidth = 0
        
        
        
        
        
        let allowMultipleDirectoriesLocal = allowMultipleDirectories
        let darkFloatArrayLocal = darkFloatArray
        Task{
        let lastDirectoryInitiator :URL = imageArray[0].deletingLastPathComponent()
         
        let _ = await withTaskGroup(of: Void.self) {taskGroup in
            
            for item in imageArray{
                taskGroup.addTask{
            
        autoreleasepool {
            var directoryNumber = 1
            var directoryIdentifier = "\(directoryNumber)"
            var imageWidthLocal = 0
            var imageHeightLocal = 0
            var rawDataFromFITSFileLocal : ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)?
            var lastDirectory = lastDirectoryInitiator
            var extractData = ExtractDataClass()
                let selectedFile: URL = item

                    print("Selected file is", selectedFile)

                    //trying to get access to url contents
                    if (CFURLStartAccessingSecurityScopedResource(selectedFile as CFURL)) {


                        guard let read_data = try! FitsFile.read(contentsOf: selectedFile) else { return }
                        let prime = read_data.prime
//                            print(prime)
                        prime.v_complete(onError: {_ in
                            print("CGImage creation error")
                        }) { result in

                                rawDataFromFITSFileLocal = result

                            let floatDataFromFITSFile :[Float] = extractData.extractFloatData(Data: rawDataFromFITSFileLocal!)

                            //Buffer from FITS File
                            let buffer = rawDataFromFITSFileLocal!.1
                            //destination buffer

                            //Checking for matching image size
                            if ((imageWidthLocal == 0) && (imageHeightLocal == 0)){

                                imageWidthLocal = Int(buffer.width)
                                imageHeightLocal = Int(buffer.height)

                            }
                            else if (imageWidthLocal != Int(buffer.width)) || (imageHeightLocal != Int(buffer.height)){

                                print("Image sizes do not match.")
                                return
                            }


                            //Doing the subtraction
                            var darkCorrectFloat = vDSP.subtract(floatDataFromFITSFile, darkFloatArrayLocal)

                          //  darkCorrectFloat = vDSP.absolute(darkCorrectFloat)

//                                print(floatDataFromFITSFile[0], darkFloatArray[0], darkCorrectFloat[0])
//                                print(floatDataFromFITSFile[2001], darkFloatArray[2001], darkCorrectFloat[2001])
//                                print(floatDataFromFITSFile[8001], darkFloatArray[8001], darkCorrectFloat[8001])

                            //var darkCorrectFloat = vDSP.add(0.0, floatDataFromFITSFile)


                            //Setting negative values to zero
                            for index in stride(from: 0, to: darkCorrectFloat.count, by: 1) {

                                if darkCorrectFloat[index] < 0.0 {

                                    darkCorrectFloat[index] = 0.0
                                }

                            }

                            let min = darkCorrectFloat.min()

                            //vDSP.add(abs(min!), darkCorrectFloat, result: &darkCorrectFloat)

                            let floatData :[FITSByte_F] = darkCorrectFloat.bigEndian

                            let myPrimaryHDU = PrimaryHDU(width: imageWidthLocal, height: imageHeightLocal, vectors: floatData)

                            let file = FitsFile(prime: myPrimaryHDU)

                            let filePath = URL(fileURLWithPath: NSHomeDirectory())
                            print(filePath)

                            var newFileURLString = filePath.absoluteString + "/Pictures/darkCorrected" + selectedFile.lastPathComponent
                            print(newFileURLString)
                            let currentDirectory = selectedFile.deletingLastPathComponent()

                            if (currentDirectory != lastDirectory){

                                lastDirectory = currentDirectory
                                directoryNumber += 1
                                directoryIdentifier = "\(directoryNumber)"


                            }

                            if(allowMultipleDirectoriesLocal){

                                newFileURLString = filePath.absoluteString + "/Pictures/darkCorrected_" + directoryIdentifier + selectedFile.lastPathComponent

                            }



                            let url = URL(string: newFileURLString)
                            print(url)

                            file.write(to: url!, onError: { error in
                                print(error)
                            })
                            {
                                // file written

                                print("File written")
                            }

                        }

                        //done accessing the url
                        CFURLStopAccessingSecurityScopedResource(selectedFile as CFURL)

                    }
                    else {
                        print("Permission error!")
                    }
                            }
                                    }
                    
                }
                
            }
        }
        }
         
         
         
        
//        for item in imageArray
//
//        {
//            autoreleasepool {
//                    let selectedFile: URL = item
//
//                        print("Selected file is", selectedFile)
//
//                        //trying to get access to url contents
//                        if (CFURLStartAccessingSecurityScopedResource(selectedFile as CFURL)) {
//
//
//                            guard let read_data = try! FitsFile.read(contentsOf: selectedFile) else { return }
//                            let prime = read_data.prime
////                            print(prime)
//                            prime.v_complete(onError: {_ in
//                                print("CGImage creation error")
//                            }) { result in
//
//                                    rawDataFromFITSFile = result
//
//                                let floatDataFromFITSFile :[Float] = self.extractFloatData(Data: rawDataFromFITSFile!)
//
//                                //Buffer from FITS File
//                                let buffer = rawDataFromFITSFile!.1
//                                //destination buffer
//
//                                //Checking for matching image size
//                                if ((imageWidth == 0) && (imageHeight == 0)){
//
//                                    imageWidth = Int(buffer.width)
//                                    imageHeight = Int(buffer.height)
//
//                                }
//                                else if (imageWidth != Int(buffer.width)) || (imageHeight != Int(buffer.height)){
//
//                                    print("Image sizes do not match.")
//                                    return
//                                }
//
//
//                                //Doing the subtraction
//                                var darkCorrectFloat = vDSP.subtract(floatDataFromFITSFile, darkFloatArray)
//
//                              //  darkCorrectFloat = vDSP.absolute(darkCorrectFloat)
//
////                                print(floatDataFromFITSFile[0], darkFloatArray[0], darkCorrectFloat[0])
////                                print(floatDataFromFITSFile[2001], darkFloatArray[2001], darkCorrectFloat[2001])
////                                print(floatDataFromFITSFile[8001], darkFloatArray[8001], darkCorrectFloat[8001])
//
//                                //var darkCorrectFloat = vDSP.add(0.0, floatDataFromFITSFile)
//
//
//                                //Setting negative values to zero
//                                for index in stride(from: 0, to: darkCorrectFloat.count, by: 1) {
//
//                                    if darkCorrectFloat[index] < 0.0 {
//
//                                        darkCorrectFloat[index] = 0.0
//                                    }
//
//                                }
//
//                                let min = darkCorrectFloat.min()
//
//                                //vDSP.add(abs(min!), darkCorrectFloat, result: &darkCorrectFloat)
//
//                                let floatData :[FITSByte_F] = darkCorrectFloat.bigEndian
//
//                                let myPrimaryHDU = PrimaryHDU(width: imageWidth, height: imageHeight, vectors: floatData)
//
//                                let file = FitsFile(prime: myPrimaryHDU)
//
//                                let filePath = URL(fileURLWithPath: NSHomeDirectory())
//                                print(filePath)
//
//                                var newFileURLString = filePath.absoluteString + "/Pictures/darkCorrected" + selectedFile.lastPathComponent
//                                print(newFileURLString)
//                                let currentDirectory = selectedFile.deletingLastPathComponent()
//
//                                if (currentDirectory != lastDirectory){
//
//                                    lastDirectory = currentDirectory
//                                    directoryNumber += 1
//                                    directoryIdentifier = "\(directoryNumber)"
//
//
//                                }
//
//                                if(allowMultipleDirectories){
//
//                                    newFileURLString = filePath.absoluteString + "/Pictures/darkCorrected_" + directoryIdentifier + selectedFile.lastPathComponent
//
//                                }
//
//
//
//                                let url = URL(string: newFileURLString)
//                                print(url)
//
//                                file.write(to: url!, onError: { error in
//                                    print(error)
//                                })
//                                {
//                                    // file written
//
//                                    print("File written")
//                                }
//
//
//
//
//                            }
//
//
//                            //done accessing the url
//                            CFURLStopAccessingSecurityScopedResource(selectedFile as CFURL)
//
//
//                        }
//                        else {
//                            print("Permission error!")
//                        }
//                      }
//                      }
//                   }
    
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

struct SubtractDarkView_Previews: PreviewProvider {
    static var previews: some View {
        SubtractDarkView()
    }
}
