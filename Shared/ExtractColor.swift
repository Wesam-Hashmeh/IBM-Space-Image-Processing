//
//  ExtractColor.swift
//  ExtractColor
//
//  Created by Jeff_Terry on 11/8/21.
//

import SwiftUI
import UniformTypeIdentifiers
import FITS
import FITSKit
import Accelerate

struct ExtractColor: View {
        
    @EnvironmentObject var listOfDocuments: DocumentList
    
    @FocusedBinding(\.document) var document
    
    @State var dataFloat :DocumentBinding? = nil
    @State var dataWidth :UInt? = nil
    @State var dataHeight :UInt? = nil
    
    @State var selectingFilesToColorConvert: Bool = false
    
    @State var selectingFilesToSave: Bool = false
    
//    @State var rawDataFromFITSFile : ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)?
    
    @State var imageHeight = 0
    @State var imageWidth = 0
    
//    @State var greenMultiply :Float = 1.5
//    @State var redMultiply :Float = 1.0
//    @State var blueMultiply :Float = 0.6
    
    @State var greenMultiply :Float = 1.0
     @State var redMultiply :Float = 1.0
     @State var blueMultiply :Float = 1.0
    
//    @State var greenMultiply :Float = 2.6
//    @State var redMultiply :Float = 1.0
//    @State var blueMultiply :Float = 3.8
    
    @State var colorFloatArray :[Float] = []
    
    @State var colorDocument = FITSDocumentDocument(text: "Hello, world!")
    
    @State var colorType = "RGGB"
    
    @State var bayerOrientationArray = ["RGGB", "BGGR"]
    
    @State var selectedImage = ""
    
    @State var imageArray :[URL] = []
    
    @State var darkImage :CGImage?
        
    var body: some View {
        
        VStack{
            
            Spacer()
            
            Button("Select Files To Process") {
                imageArray.removeAll()
                selectingFilesToColorConvert.toggle()
                    }
                .fileImporter(
                        isPresented: $selectingFilesToColorConvert,
                        allowedContentTypes: [.fitDocument],
                        allowsMultipleSelection: true,
                        onCompletion: { result in
                            print("Picked: \(result)")
                            
                            let imageFileURL = try? result.get()

                            imageArray.append(contentsOf: imageFileURL!)

                            print(imageArray)
                        })
            
            Spacer()
            
            Button("Color Convert The Image Files"){
                
                print(imageArray)
                
                loadAndColorConvertImage()
                
            }
                
                
            Spacer()
                
            Picker("Bayer Grid Orientation", selection: $colorType) {
                ForEach(bayerOrientationArray, id: \.self) {
                                Text($0)
                            }
                }
                
            
//            Button("Save"){
//
//                saveFile()
//                selectingFilesToSave = true
//
//            }
//            .fileExporter(isPresented: $selectingFilesToSave, document: darkDocument, contentType: .fitDocument, defaultFilename: "Dark", onCompletion: { result in
//                print("Picked: \(result)")
//
////                let fileUrlsToAdd = try? result.get()
////
////                imageArray.append(contentsOf: fileUrlsToAdd!)
////
////                print(imageArray)
//            })
            
            Spacer()
            
            
        }
            
            VStack{
                //rawImage?.resizable().scaledToFit()
                if (darkImage != nil){
                    Image((darkImage!), scale: 2.0, label: Text("Raw")).resizable().scaledToFit()
                }
            }

            
        
        
        
                
    }

    func saveFile(){
        
//        let floatData :[FITSByte_F] = darkDocument.rawFloatData.bigEndian
//
//        darkDocument.myPrimaryHDU = PrimaryHDU(width: imageWidth, height: imageHeight, vectors: floatData)
//
//
//        print(darkDocument.myPrimaryHDU)
    }
    

    
    func loadAndColorConvertImage(){
        
        imageHeight = 0
        imageWidth = 0
        
        let colorTypeLocal = colorType

        
        if colorTypeLocal == "RGGB"{
           
            Task{
            let _ = await withTaskGroup(of: Void.self) {taskGroup in
            
            for item in imageArray{
                
                
                    
                    taskGroup.addTask{
                    autoreleasepool{
                        var rowRemainder = 0
                        var columnRemainder = 0
                        var imageWidthLocal = 0
                        var imageHeightLocal = 0
                        var extractData = ExtractDataClass()
                        var rawDataFromFITSFile : ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)?
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
                                        
                                        let floatDataFromFITSFile :[Float] = extractData.extractFloatData(Data: rawDataFromFITSFile!)
                                        
                                        //Buffer from FITS File
                                        let buffer = rawDataFromFITSFile!.1
                                        //destination buffer
                                        
                                        if ((imageWidthLocal == 0) && (imageHeightLocal == 0)){
                                            
                                            imageWidthLocal = Int(buffer.width)
                                            imageHeightLocal = Int(buffer.height)
                                            
                                        }
                                        else if (imageWidthLocal != Int(buffer.width)) || (imageHeightLocal != Int(buffer.height)){
                                            
                                            print("Image sizes do not match.")
                                            return
                                        }
                                        
                                        var greenMinimum :Float = 100000.0
                                        var redMinimum :Float = 100000.0
                                        var blueMinimum :Float = 100000.0
                                        var luminanceMinimum :Float = 100000.0
                                        
                                        var greenImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)
                                        var greenStretchedImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)
                                        
                                        var redImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)
                                        var redStretchedImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)

                                        var blueImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)
                                        var blueStretchedImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)
                                        
                                        var luminanceImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)
                                        var luminanceStretchedImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)

                                        

                                            
                                            
                                            /*   Color Conversion   */
                                            
                                            // start in Second Row and Second Column
                                            
                                            for row in stride(from: 1, to: imageHeightLocal-1, by: 1){
                                                
                                                
                                                for column in stride(from: 1, to: imageWidthLocal-1, by: 1){
                                                    
                                                    //Calculate color position
                                                    
                                                    rowRemainder = row % 2
                                                    columnRemainder = column % 2
                                                    
                                                    if (rowRemainder == 0){
                                                        
                                                        
                                                        if (columnRemainder == 1){
                                                            
                                                            //rowRemainder == 0
                                                            //columnRemainder == 1
                                                            
                                                            //It is green already
                                                            
                                                            greenImage[column + row * imageWidthLocal] = floatDataFromFITSFile[column + row * imageWidthLocal]
                                                            
                                                            //R(column,row) = (D(column-1, row) + D(column+1, row))/2
                                                            
                                                            redImage[column + row * imageWidthLocal] = 0.5*(floatDataFromFITSFile[column + 1 + (row) * imageWidthLocal] + floatDataFromFITSFile[column - 1 + (row) * imageWidthLocal])
                                                            
                                                            //  B(column, row) = ( D(column, row-1) + D(column, row+1))/2
                                                            
                                                            blueImage[column + row * imageWidthLocal] = 0.5*(floatDataFromFITSFile[column + (row-1) * imageWidthLocal] + floatDataFromFITSFile[column + (row+1) * imageWidthLocal])
                                                            
                                                            
                                                            
                                                        }
                                                        else{
                                                            
                                                            //rowRemainder == 0
                                                            //columnRemainder == 0
                                                            
                                                            //G(column,row) = ( G(column-1, row) + G( column+1, row)  +G(column, row+1) + G (column, row - 1) )/4
                                                            
                                                            greenImage[column + row * imageWidthLocal] = 0.25*(floatDataFromFITSFile[column + (row-1) * imageWidthLocal] + floatDataFromFITSFile[column + (row+1) * imageWidthLocal] + floatDataFromFITSFile[(column+1) + row * imageWidthLocal] + floatDataFromFITSFile[(column-1) + row * imageWidthLocal])
                                                            
                                                            //It is red already
                                                            
                                                            redImage[column + row * imageWidthLocal] = floatDataFromFITSFile[column + row * imageWidthLocal]
                                                            
                                                            //  B(column, row) = ( D(column-1, row-1) + D(column+1, row-1) + D(column-1, row+1) +  D(column+1, row+1) )/4
                                                            
                                                            blueImage[column + row * imageWidthLocal] = 0.25*(floatDataFromFITSFile[column - 1 + (row-1) * imageWidthLocal] + floatDataFromFITSFile[column + 1 + (row+1) * imageWidthLocal] + floatDataFromFITSFile[(column-1) + (row+1) * imageWidthLocal] + floatDataFromFITSFile[(column+1) + (row+1) * imageWidthLocal])
                                                            
                                                            
                                                        }
                                                        
                                                    }
                                                    else{
                                                        
                                                        if(columnRemainder == 1){
                                                            
                                                            //rowRemainder == 1
                                                            //columnRemainder == 1
                                                            
                                                            //G(column,row) = ( D(column-1, row) + D( column+1, row)  + D(column, row+1) + D(column, row - 1) )/4
                                                            
                                                            greenImage[column + row * imageWidthLocal] = 0.25*(floatDataFromFITSFile[column - 1 + (row) * imageWidthLocal] + floatDataFromFITSFile[column + 1 + (row) * imageWidthLocal] + floatDataFromFITSFile[column + (row+1) * imageWidthLocal] + floatDataFromFITSFile[column + (row-1) * imageWidthLocal])
                                                            
                                                            //  R(column, row) = ( D(column-1, row-1) + D(column+1, row-1) + D(column-1, row+1) +  D(column+1, row+1) )/4
                                                            
                                                            redImage[column + row * imageWidthLocal] = 0.25*(floatDataFromFITSFile[column - 1 + (row-1) * imageWidthLocal] + floatDataFromFITSFile[column + 1 + (row-1) * imageWidthLocal] + floatDataFromFITSFile[column - 1 + (row+1) * imageWidthLocal] + floatDataFromFITSFile[column + 1  + (row+1) * imageWidthLocal])
                                                            
                                                            // It is blue already
                                                            
                                                            blueImage[column + row * imageWidthLocal] = floatDataFromFITSFile[column + row * imageWidthLocal]
                                                            
                                                            
                                                            
                                                            
                                                        }
                                                        else{
                                                            
                                                            
                                                            //rowRemainder = 1
                                                            //columnRemainder = 0
                                                            
                                                            
                                                            //It is green already
                                                            
                                                            greenImage[column + row * imageWidthLocal] = floatDataFromFITSFile[column + row * imageWidthLocal]
                                                            
                                                            
                                                            //  R(column, row) = ( D(column, row-1) + D(column, row+1))/2
                                                            
                                                            redImage[column + row * imageWidthLocal] = 0.5*(floatDataFromFITSFile[column + (row-1) * imageWidthLocal] + floatDataFromFITSFile[column + (row+1) * imageWidthLocal])
                                                            
                                                            
                                                            //B(column,row) = ( D(column-1, row) + D(column+1, row)  )/2
                                                            
                                                            blueImage[column + row * imageWidthLocal] = 0.5*(floatDataFromFITSFile[column - 1 + (row) * imageWidthLocal] + floatDataFromFITSFile[column + 1 + (row) * imageWidthLocal])
                                                            
                                                            
                                                            
                                                        }
                                                        
                                                        
                                                        
                                                    }
                                                    
                                                    if (greenMinimum > greenImage[column + row * imageWidthLocal]) {
                                                        
                                                        greenMinimum = greenImage[column + row * imageWidthLocal]
                                                        
                                                    }
                                                    
                                                    if (redMinimum > redImage[column + row * imageWidthLocal]) {
                                                        
                                                        redMinimum = redImage[column + row * imageWidthLocal]
                                                        
                                                    }
                                                    
                                                    if (blueMinimum > blueImage[column + row * imageWidthLocal]) {
                                                        
                                                        blueMinimum = blueImage[column + row * imageWidthLocal]
                                                        
                                                    }
                                                    
                                                    
                                                }
                                                
                                                
                                            }
                                            
                                            
                                            
                                            
                                        

                                        
                                        
                                        var greenMinFloat = vDSP.add(-(greenMinimum), greenImage)
                                        
                                        for index in stride(from: 0, to: greenImage.count, by: 1) {
                                            
                                            if greenImage[index] < 0.0 {
                                                
                                                greenImage[index] = 0.0
                                            }
                                            
                                        }
                                        
                                        var redMinFloat = vDSP.add(-(redMinimum), redImage)
                                        
                                        for index in stride(from: 0, to: redImage.count, by: 1) {
                                            
                                            if redImage[index] < 0.0 {
                                                
                                                redImage[index] = 0.0
                                            }
                                            
                                        }
                                        
                                        var blueMinFloat = vDSP.add(-(blueMinimum), blueImage)
                                        
                                        for index in stride(from: 0, to: blueImage.count, by: 1) {
                                            
                                            if blueImage[index] < 0.0 {
                                                
                                                blueImage[index] = 0.0
                                            }
                                            
                                        }
                                        
                                    
                                        
        //                                greenImage = vDSP.multiply(greenMultiply, greenMinFloat)
        //                                redImage = vDSP.multiply(redMultiply, redMinFloat)
        //                                blueImage = vDSP.multiply(blueMultiply, blueMinFloat)
        //
                                        
                                        let histogramcount :UInt32 = 4096
                                        var histogramZeroLevel = 0.0
                                        var histogramAboveBackground = 20.0
                                        var cutoff = 0.0
                                        
                                        
                                        greenImage.withUnsafeMutableBufferPointer {pointerToGreenFloats in
                                        
                                            let sourceRowBytes :Int = Int(imageWidthLocal) * MemoryLayout<Float>.size
                                            var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToGreenFloats.baseAddress, height: vImagePixelCount(imageHeightLocal), width: vImagePixelCount(imageWidthLocal), rowBytes: sourceRowBytes)
                                            
                                            let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
                                            
                                            
                                            let histogramMax = histogramBin.max()
                                            
                                            let index = histogramBin.firstIndex(of: histogramMax!)
                                            
                                            var histogramCounter = index!
                                            
                                            let bottomTenPercent = histogramMax!/10
                                           
                                            while((histogramBin[histogramCounter] >= bottomTenPercent) && (histogramCounter > 1) ){
                                        
                                                    histogramCounter -= 1
                                            
                                            }
                                            
                                            
                                            
                                            
        //                                    //calculate the 0 level of the histogram
        //                                    for i in stride(from: 3, to: 22, by: 1){
        //
        //                                        histogramZeroLevel += Double(histogramBin[i])
        //
        //                                    }
        //
        //                                    histogramZeroLevel /= Double(20.0)
        //
        //
        //
        //                                    cutoff = histogramZeroLevel*histogramAboveBackground
        //
        //                                    var histogramCounter = 3
        //
        //                                    while(histogramBin[histogramCounter] < UInt(cutoff)){
        //
        //                                        histogramCounter += 1
        //
        //                                    }
        //
                                            greenMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
                                        
                                            
                                        }
                                        
                                        greenStretchedImage = vDSP.add(-greenMinimum, greenImage)
                                 
                                        //greenImage = vDSP.multiply(1.0/(1.10-greenMinimum), greenStretchedImage)
                                        
                                        //greenImage = vDSP.clip(greenImage, to: 0.0...1.0)
                                        
                                        
                                        //come back to this
                                        //greenImage = vDSP.add(-greenMinimum, greenImage)
                                        
                                        cutoff = 0.0
                                        histogramAboveBackground = 75.0
                                        
                                        blueImage.withUnsafeMutableBufferPointer {pointerToBlueFloats in
                                        
                                            let sourceRowBytes :Int = Int(imageWidthLocal) * MemoryLayout<Float>.size
                                            var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToBlueFloats.baseAddress, height: vImagePixelCount(imageHeightLocal), width: vImagePixelCount(imageWidthLocal), rowBytes: sourceRowBytes)
                                            
                                            let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
                                            
                                            let histogramMax = histogramBin.max()
                                            
                                            let index = histogramBin.firstIndex(of: histogramMax!)
                                            
                                            var histogramCounter = index!
                                            
                                            let bottomTenPercent = histogramMax!/10
                                            
                                            while(histogramBin[histogramCounter] >= bottomTenPercent){
                                        
                                                    histogramCounter -= 1
                                            
                                            }
                                            
                                           // histogramZeroLevel = 0.0
                                            
        //                                    //calculate the 0 level of the histogram
        //                                    for i in stride(from: 3, to: 22, by: 1){
        //
        //                                        histogramZeroLevel += Double(histogramBin[i])
        //
        //                                    }
        //
        //                                    histogramZeroLevel /= Double(20.0)
        //
        //
        //
        //                                    cutoff = histogramZeroLevel*histogramAboveBackground
        //
        //                                    var histogramCounter = 3
        //
        //                                    while(histogramBin[histogramCounter] < UInt(cutoff)){
        //
        //                                        histogramCounter += 1
        //
        //                                    }
        //
        //                                    print("Blue", cutoff, histogramCounter)
            
                                            blueMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
                                            
                                            print("Blue minimum", blueMinimum)
                                        
                                            
                                        }
                                        
                                        blueStretchedImage = vDSP.add(-blueMinimum, blueImage)
                                      
                                        //blueImage = vDSP.multiply(1.0/(1.0-blueMinimum), blueStretchedImage)
                                        
                                        //blueImage = vDSP.clip(blueImage, to: 0.0...1.0)
                                        
                                        //come back to this
                                        //blueImage = vDSP.add(-blueMinimum, blueImage)
                                        
                                        histogramAboveBackground = 0.0
                                        cutoff = 0.0
                                        
                                        redImage.withUnsafeMutableBufferPointer {pointerToRedFloats in
                                                                                
                                            let sourceRowBytes :Int = Int(imageWidthLocal) * MemoryLayout<Float>.size
                                            var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToRedFloats.baseAddress, height: vImagePixelCount(imageHeightLocal), width: vImagePixelCount(imageWidthLocal), rowBytes: sourceRowBytes)
                                            
                                            let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
                                            
                                            let histogramMax = histogramBin.max()
                                            
                                            let index = histogramBin.firstIndex(of: histogramMax!)
                                            
                                            var histogramCounter = index!
                                            
                                            let bottomTenPercent = histogramMax!/10
                                            
                                            while(histogramBin[histogramCounter] >= bottomTenPercent){
                                        
                                                    histogramCounter -= 1
                                                
                                                if (histogramCounter == 0) {
                                                    
                                                    break
                                                }
                                            
                                            }
                                            
                                           // histogramZeroLevel = 0.0
                                            
        //                                    //calculate the 0 level of the histogram
        //                                    for i in stride(from: 3, to: 22, by: 1){
        //
        //                                        histogramZeroLevel += Double(histogramBin[i])
        //
        //                                    }
        //
        //                                    histogramZeroLevel /= Double(20.0)
        //
        //
        //
        //                                    cutoff = histogramZeroLevel*histogramAboveBackground
        //
        //                                    var histogramCounter = 3
        //
        //                                    while(histogramBin[histogramCounter] < UInt(cutoff)){
        //
        //                                        histogramCounter += 1
        //
        //                                    }
            
                                            redMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
                                                
        //                                    var rawEqualizedvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToEqualizedRedFloats.baseAddress, height: vImagePixelCount(imageHeight), width: vImagePixelCount(imageWidth), rowBytes: sourceRowBytes)
                                            
                                                
                                                
                                                
                                            
                                                
                                        
                                            
                                        }
                                        
                                        
                                        
                                        redStretchedImage = vDSP.add(-redMinimum, redImage)
                                       
                                        //redImage = vDSP.multiply(1.0/(0.75-redMinimum), redStretchedImage)
                                        
                                        //redImage = vDSP.clip(redImage, to: 0.0...1.0)
                                       //come back to this
                                        //redImage = vDSP.add(-redMinimum, redImage)
        //                                redImage = vDSP.add((1.0/Float(histogramcount)*600), redImage)
                                        
                                        
                                        //redImage = vDSP.add(0.0, redEqualizedImage)
                                        
                                        
                                        histogramAboveBackground = 10.0
                                        cutoff = 0.0
                                        
                                        
                                        //Luminance Image
                                        
                                        //grayValue = 0.222*red + 0.707*green + 0.071*blue.
                                        
                                        luminanceMinimum = 0.0
                                        
                                        var gray = vDSP.add(multiplication: (a: redImage, b: Float(0.222)), multiplication: (c: greenImage, d: Float(0.707)))
                                        
                                        
                                        luminanceImage = vDSP.add(multiplication: (a: blueImage, b: Float(0.071)), gray)
                                        
                                        
                                        luminanceImage.withUnsafeMutableBufferPointer {pointerToLuminanceFloats in
                                                                                
                                            let sourceRowBytes :Int = Int(imageWidthLocal) * MemoryLayout<Float>.size
                                            var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToLuminanceFloats.baseAddress, height: vImagePixelCount(imageHeightLocal), width: vImagePixelCount(imageWidthLocal), rowBytes: sourceRowBytes)
                                            
                                            let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
                                            
                                            let histogramMax = histogramBin.max()
                                            
                                            let index = histogramBin.firstIndex(of: histogramMax!)
                                            
                                            var histogramCounter = index!
                                            
                                            let bottomTenPercent = histogramMax!/10
                                            
                                            while(histogramBin[histogramCounter] >= bottomTenPercent){
                                        
                                                    histogramCounter -= 1
                                            
                                            }
                                            
                                           // histogramZeroLevel = 0.0
                                            
        //                                    //calculate the 0 level of the histogram
        //                                    for i in stride(from: 3, to: 22, by: 1){
        //
        //                                        histogramZeroLevel += Double(histogramBin[i])
        //
        //                                    }
        //
        //                                    histogramZeroLevel /= Double(20.0)
        //
        //
        //
        //                                    cutoff = histogramZeroLevel*histogramAboveBackground
        //
        //                                    var histogramCounter = 3
        //
        //                                    while(histogramBin[histogramCounter] < UInt(cutoff)){
        //
        //                                        histogramCounter += 1
        //
        //                                    }
            
                                            luminanceMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
                                                
        //                                    var rawEqualizedvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToEqualizedRedFloats.baseAddress, height: vImagePixelCount(imageHeight), width: vImagePixelCount(imageWidth), rowBytes: sourceRowBytes)
                                            
                                                
                                                
                                                
                                            
                                                
                                        
                                            
                                        }
                                        
                                        
                                        
                                        luminanceStretchedImage = vDSP.add(-luminanceMinimum, luminanceImage)
                                        
                                        //luminanceImage = vDSP.multiply(1.0/(0.75-luminanceMinimum), luminanceStretchedImage)
                                        
                                        //luminanceImage = vDSP.clip(luminanceImage, to: 0.0...1.0)

                                        
                                        
        //                                luminanceImage.withUnsafeMutableBufferPointer {pointerToLuminanceFloats in
        //
        //                                    let sourceRowBytes :Int = Int(imageWidth) * MemoryLayout<Float>.size
        //                                    var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToLuminanceFloats.baseAddress, height: vImagePixelCount(imageHeight), width: vImagePixelCount(imageWidth), rowBytes: sourceRowBytes)
        //
        //                                    let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
        //
        //                                    histogramZeroLevel = 0.0
        //                                    cutoff = 0.0
        //
        //                                    //calculate the 0 level of the histogram
        //                                    for i in stride(from: 3, to: 22, by: 1){
        //
        //                                        histogramZeroLevel += Double(histogramBin[i])
        //
        //                                    }
        //
        //                                    histogramZeroLevel /= Double(20.0)
        //
        //
        //
        //                                    cutoff = histogramZeroLevel*histogramAboveBackground
        //
        //                                    var histogramCounter = 3
        //
        //                                    while(histogramBin[histogramCounter] < UInt(cutoff)){
        //
        //                                        histogramCounter += 1
        //
        //                                    }
        //
        //                                    luminanceMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
        //
        //
        //                                }
        //
        //                                luminanceImage = vDSP.add(-luminanceMinimum, luminanceImage)
        //
                                        
                                        var floatData :[FITSByte_F] = greenImage.bigEndian

                                        var myPrimaryHDU = PrimaryHDU(width: imageWidthLocal, height: imageHeightLocal, vectors: floatData)

                                        var file = FitsFile(prime: myPrimaryHDU)

                                        var filePath = URL(fileURLWithPath: NSHomeDirectory())

        //                                let filePath = selectedFile.deletingLastPathComponent()
        //
                                        var newFileURLString = filePath.absoluteString + "/Pictures/Green" + selectedFile.lastPathComponent



                                        var url = URL(string: newFileURLString)
                                        print(url)

                                        file.write(to: url!, onError: { error in
                                            print(error)
                                        }) {
                                            // file written

                                            print("File written")
                                        }
                                        
                                        
                                        floatData = redImage.bigEndian

                                        myPrimaryHDU = PrimaryHDU(width: imageWidthLocal, height: imageHeightLocal, vectors: floatData)

                                        file = FitsFile(prime: myPrimaryHDU)

                                        filePath = URL(fileURLWithPath: NSHomeDirectory())

        //                                let filePath = selectedFile.deletingLastPathComponent()
        //
                                        newFileURLString = filePath.absoluteString + "/Pictures/Red" + selectedFile.lastPathComponent



                                        url = URL(string: newFileURLString)
                                        print(url)

                                        file.write(to: url!, onError: { error in
                                            print(error)
                                        }) {
                                            // file written

                                            print("File written")
                                        }
                                        
                                        
                                        floatData = blueImage.bigEndian

                                        myPrimaryHDU = PrimaryHDU(width: imageWidthLocal, height: imageHeightLocal, vectors: floatData)

                                        file = FitsFile(prime: myPrimaryHDU)

                                        filePath = URL(fileURLWithPath: NSHomeDirectory())

        //                                let filePath = selectedFile.deletingLastPathComponent()
        //
                                        newFileURLString = filePath.absoluteString + "/Pictures/Blue" + selectedFile.lastPathComponent



                                        url = URL(string: newFileURLString)
                                        print(url)

                                        file.write(to: url!, onError: { error in
                                            print(error)
                                        }) {
                                            // file written

                                            print("File written")
                                        }
                                        
                                        floatData = luminanceImage.bigEndian

                                        myPrimaryHDU = PrimaryHDU(width: imageWidthLocal, height: imageHeightLocal, vectors: floatData)

                                        file = FitsFile(prime: myPrimaryHDU)

                                        filePath = URL(fileURLWithPath: NSHomeDirectory())

        //                                let filePath = selectedFile.deletingLastPathComponent()
        //
                                        newFileURLString = filePath.absoluteString + "/Pictures/Luminance" + selectedFile.lastPathComponent



                                        url = URL(string: newFileURLString)
                                        print(url)

                                        file.write(to: url!, onError: { error in
                                            print(error)
                                        }) {
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
        else if colorTypeLocal == "BGGR"{
            
            Task{
            let _ = await withTaskGroup(of: Void.self) {taskGroup in
            
            for item in imageArray{
                
                    
                    taskGroup.addTask{
                    autoreleasepool{
                        var rowRemainder = 0
                        var columnRemainder = 0
                        var imageWidthLocal = 0
                        var imageHeightLocal = 0
                        var extractData = ExtractDataClass()
                        var rawDataFromFITSFile : ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)?
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
                                        
                                        let floatDataFromFITSFile :[Float] = extractData.extractFloatData(Data: rawDataFromFITSFile!)
                                        
                                        //Buffer from FITS File
                                        let buffer = rawDataFromFITSFile!.1
                                        //destination buffer
                                        
                                        if ((imageWidthLocal == 0) && (imageHeightLocal == 0)){
                                            
                                            imageWidthLocal = Int(buffer.width)
                                            imageHeightLocal = Int(buffer.height)
                                            
                                        }
                                        else if (imageWidthLocal != Int(buffer.width)) || (imageHeightLocal != Int(buffer.height)){
                                            
                                            print("Image sizes do not match.")
                                            return
                                        }
                                        
                                        var greenMinimum :Float = 100000.0
                                        var redMinimum :Float = 100000.0
                                        var blueMinimum :Float = 100000.0
                                        var luminanceMinimum :Float = 100000.0
                                        
                                        var greenImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)
                                        var greenStretchedImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)
                                        
                                        var redImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)
                                        var redStretchedImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)

                                        var blueImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)
                                        var blueStretchedImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)
                                        
                                        var luminanceImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)
                                        var luminanceStretchedImage :[Float] = Array(repeating: 0.0, count: imageWidthLocal*imageHeightLocal)

                                        
                                         
                                            
                                            /*   Color Conversion   */
                                            
                                            // Red and Blue are Swapped from Above
                                            
                                            // start in Second Row and Second Column
                                            
                                            for row in stride(from: 1, to: imageHeightLocal-1, by: 1){
                                                
                                                
                                                for column in stride(from: 1, to: imageWidthLocal-1, by: 1){
                                                    
                                                    //Calculate color position
                                                    
                                                    rowRemainder = row % 2
                                                    columnRemainder = column % 2
                                                    
                                                    if (rowRemainder == 0){
                                                        
                                                        
                                                        if (columnRemainder == 1){
                                                            
                                                            //rowRemainder == 0
                                                            //columnRemainder == 1
                                                            
                                                            //It is green already
                                                            
                                                            greenImage[column + row * imageWidthLocal] = floatDataFromFITSFile[column + row * imageWidthLocal]
                                                            
                                                            //B(column,row) = (D(column-1, row) + D(column+1, row))/2
                                                            
                                                            blueImage[column + row * imageWidthLocal] = 0.5*(floatDataFromFITSFile[column + 1 + (row) * imageWidthLocal] + floatDataFromFITSFile[column - 1 + (row) * imageWidthLocal])
                                                            
                                                            //  R(column, row) = ( D(column, row-1) + D(column, row+1))/2
                                                            
                                                            redImage[column + row * imageWidthLocal] = 0.5*(floatDataFromFITSFile[column + (row-1) * imageWidthLocal] + floatDataFromFITSFile[column + (row+1) * imageWidthLocal])
                                                            
                                                            
                                                            
                                                        }
                                                        else{
                                                            
                                                            //rowRemainder == 0
                                                            //columnRemainder == 0
                                                            
                                                            //G(column,row) = ( G(column-1, row) + G( column+1, row)  +G(column, row+1) + G (column, row - 1) )/4
                                                            
                                                            greenImage[column + row * imageWidthLocal] = 0.25*(floatDataFromFITSFile[column + (row-1) * imageWidthLocal] + floatDataFromFITSFile[column + (row+1) * imageWidthLocal] + floatDataFromFITSFile[(column+1) + row * imageWidthLocal] + floatDataFromFITSFile[(column-1) + row * imageWidthLocal])
                                                            
                                                            //It is blue already
                                                            
                                                            blueImage[column + row * imageWidthLocal] = floatDataFromFITSFile[column + row * imageWidthLocal]
                                                            
                                                            //  R(column, row) = ( D(column-1, row-1) + D(column+1, row-1) + D(column-1, row+1) +  D(column+1, row+1) )/4
                                                            
                                                            redImage[column + row * imageWidthLocal] = 0.25*(floatDataFromFITSFile[column - 1 + (row-1) * imageWidthLocal] + floatDataFromFITSFile[column + 1 + (row+1) * imageWidthLocal] + floatDataFromFITSFile[(column-1) + (row+1) * imageWidthLocal] + floatDataFromFITSFile[(column+1) + (row+1) * imageWidthLocal])
                                                            
                                                            
                                                        }
                                                        
                                                    }
                                                    else{
                                                        
                                                        if(columnRemainder == 1){
                                                            
                                                            //rowRemainder == 1
                                                            //columnRemainder == 1
                                                            
                                                            //G(column,row) = ( D(column-1, row) + D( column+1, row)  + D(column, row+1) + D(column, row - 1) )/4
                                                            
                                                            greenImage[column + row * imageWidthLocal] = 0.25*(floatDataFromFITSFile[column - 1 + (row) * imageWidthLocal] + floatDataFromFITSFile[column + 1 + (row) * imageWidthLocal] + floatDataFromFITSFile[column + (row+1) * imageWidthLocal] + floatDataFromFITSFile[column + (row-1) * imageWidthLocal])
                                                            
                                                            //  B(column, row) = ( D(column-1, row-1) + D(column+1, row-1) + D(column-1, row+1) +  D(column+1, row+1) )/4
                                                            
                                                            blueImage[column + row * imageWidthLocal] = 0.25*(floatDataFromFITSFile[column - 1 + (row-1) * imageWidthLocal] + floatDataFromFITSFile[column + 1 + (row-1) * imageWidthLocal] + floatDataFromFITSFile[column - 1 + (row+1) * imageWidthLocal] + floatDataFromFITSFile[column + 1  + (row+1) * imageWidthLocal])
                                                            
                                                            // It is red already
                                                            
                                                            redImage[column + row * imageWidthLocal] = floatDataFromFITSFile[column + row * imageWidthLocal]
                                                            
                                                            
                                                            
                                                            
                                                        }
                                                        else{
                                                            
                                                            
                                                            //rowRemainder = 1
                                                            //columnRemainder = 0
                                                            
                                                            
                                                            //It is green already
                                                            
                                                            greenImage[column + row * imageWidthLocal] = floatDataFromFITSFile[column + row * imageWidthLocal]
                                                            
                                                            
                                                            //  B(column, row) = ( D(column, row-1) + D(column, row+1))/2
                                                            
                                                            blueImage[column + row * imageWidthLocal] = 0.5*(floatDataFromFITSFile[column + (row-1) * imageWidthLocal] + floatDataFromFITSFile[column + (row+1) * imageWidthLocal])
                                                            
                                                            
                                                            //R(column,row) = ( D(column-1, row) + D(column+1, row)  )/2
                                                            
                                                            redImage[column + row * imageWidthLocal] = 0.5*(floatDataFromFITSFile[column - 1 + (row) * imageWidthLocal] + floatDataFromFITSFile[column + 1 + (row) * imageWidthLocal])
                                                            
                                                            
                                                            
                                                        }
                                                        
                                                        
                                                        
                                                    }
                                                    
                                                    if (greenMinimum > greenImage[column + row * imageWidthLocal]) {
                                                        
                                                        greenMinimum = greenImage[column + row * imageWidthLocal]
                                                        
                                                    }
                                                    
                                                    if (redMinimum > redImage[column + row * imageWidthLocal]) {
                                                        
                                                        redMinimum = redImage[column + row * imageWidthLocal]
                                                        
                                                    }
                                                    
                                                    if (blueMinimum > blueImage[column + row * imageWidthLocal]) {
                                                        
                                                        blueMinimum = blueImage[column + row * imageWidthLocal]
                                                        
                                                    }
                                                    
                                                    
                                                }
                                                
                                                
                                            }
                                            
                                            
                                        
                                            
                                            
                                                                            
                                        
                                        var greenMinFloat = vDSP.add(-(greenMinimum), greenImage)
                                        
                                        for index in stride(from: 0, to: greenImage.count, by: 1) {
                                            
                                            if greenImage[index] < 0.0 {
                                                
                                                greenImage[index] = 0.0
                                            }
                                            
                                        }
                                        
                                        var redMinFloat = vDSP.add(-(redMinimum), redImage)
                                        
                                        for index in stride(from: 0, to: redImage.count, by: 1) {
                                            
                                            if redImage[index] < 0.0 {
                                                
                                                redImage[index] = 0.0
                                            }
                                            
                                        }
                                        
                                        var blueMinFloat = vDSP.add(-(blueMinimum), blueImage)
                                        
                                        for index in stride(from: 0, to: blueImage.count, by: 1) {
                                            
                                            if blueImage[index] < 0.0 {
                                                
                                                blueImage[index] = 0.0
                                            }
                                            
                                        }
                                        
                                    
                                        
        //                                greenImage = vDSP.multiply(greenMultiply, greenMinFloat)
        //                                redImage = vDSP.multiply(redMultiply, redMinFloat)
        //                                blueImage = vDSP.multiply(blueMultiply, blueMinFloat)
        //
                                        
                                        let histogramcount :UInt32 = 4096
                                        var histogramZeroLevel = 0.0
                                        var histogramAboveBackground = 20.0
                                        var cutoff = 0.0
                                        
                                        
                                        greenImage.withUnsafeMutableBufferPointer {pointerToGreenFloats in
                                        
                                            let sourceRowBytes :Int = Int(imageWidthLocal) * MemoryLayout<Float>.size
                                            var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToGreenFloats.baseAddress, height: vImagePixelCount(imageHeightLocal), width: vImagePixelCount(imageWidthLocal), rowBytes: sourceRowBytes)
                                            
                                            let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
                                            
                                            
                                            let histogramMax = histogramBin.max()
                                            
                                            let index = histogramBin.firstIndex(of: histogramMax!)
                                            
                                            var histogramCounter = index!
                                            
                                            let bottomTenPercent = histogramMax!/10
                                           
                                            while((histogramBin[histogramCounter] >= bottomTenPercent) && (histogramCounter > 1) ){
                                        
                                                    histogramCounter -= 1
                                            
                                            }
                                            
                                            
                                            
                                            
        //                                    //calculate the 0 level of the histogram
        //                                    for i in stride(from: 3, to: 22, by: 1){
        //
        //                                        histogramZeroLevel += Double(histogramBin[i])
        //
        //                                    }
        //
        //                                    histogramZeroLevel /= Double(20.0)
        //
        //
        //
        //                                    cutoff = histogramZeroLevel*histogramAboveBackground
        //
        //                                    var histogramCounter = 3
        //
        //                                    while(histogramBin[histogramCounter] < UInt(cutoff)){
        //
        //                                        histogramCounter += 1
        //
        //                                    }
        //
                                            greenMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
                                        
                                            
                                        }
                                        
                                        greenStretchedImage = vDSP.add(-greenMinimum, greenImage)
                                 
                                        //greenImage = vDSP.multiply(1.0/(1.10-greenMinimum), greenStretchedImage)
                                        
                                        //greenImage = vDSP.clip(greenImage, to: 0.0...1.0)
                                        
                                        
                                        //come back to this
                                        //greenImage = vDSP.add(-greenMinimum, greenImage)
                                        
                                        cutoff = 0.0
                                        histogramAboveBackground = 75.0
                                        
                                        blueImage.withUnsafeMutableBufferPointer {pointerToBlueFloats in
                                        
                                            let sourceRowBytes :Int = Int(imageWidthLocal) * MemoryLayout<Float>.size
                                            var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToBlueFloats.baseAddress, height: vImagePixelCount(imageHeightLocal), width: vImagePixelCount(imageWidthLocal), rowBytes: sourceRowBytes)
                                            
                                            let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
                                            
                                            let histogramMax = histogramBin.max()
                                            
                                            let index = histogramBin.firstIndex(of: histogramMax!)
                                            
                                            var histogramCounter = index!
                                            
                                            let bottomTenPercent = histogramMax!/10
                                            
                                            while((histogramCounter > 1) && histogramBin[histogramCounter] >= bottomTenPercent){
                                        
                                                    histogramCounter -= 1
                                            
                                            }
                                            
                                           // histogramZeroLevel = 0.0
                                            
        //                                    //calculate the 0 level of the histogram
        //                                    for i in stride(from: 3, to: 22, by: 1){
        //
        //                                        histogramZeroLevel += Double(histogramBin[i])
        //
        //                                    }
        //
        //                                    histogramZeroLevel /= Double(20.0)
        //
        //
        //
        //                                    cutoff = histogramZeroLevel*histogramAboveBackground
        //
        //                                    var histogramCounter = 3
        //
        //                                    while(histogramBin[histogramCounter] < UInt(cutoff)){
        //
        //                                        histogramCounter += 1
        //
        //                                    }
        //
        //                                    print("Blue", cutoff, histogramCounter)
            
                                            blueMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
                                            
                                            print("Blue minimum", blueMinimum)
                                        
                                            
                                        }
                                        
                                        blueStretchedImage = vDSP.add(-blueMinimum, blueImage)
                                      
                                        //blueImage = vDSP.multiply(1.0/(1.0-blueMinimum), blueStretchedImage)
                                        
                                        //blueImage = vDSP.clip(blueImage, to: 0.0...1.0)
                                        
                                        //come back to this
                                        //blueImage = vDSP.add(-blueMinimum, blueImage)
                                        
                                        histogramAboveBackground = 0.0
                                        cutoff = 0.0
                                        
                                        redImage.withUnsafeMutableBufferPointer {pointerToRedFloats in
                                                                                
                                            let sourceRowBytes :Int = Int(imageWidthLocal) * MemoryLayout<Float>.size
                                            var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToRedFloats.baseAddress, height: vImagePixelCount(imageHeightLocal), width: vImagePixelCount(imageWidthLocal), rowBytes: sourceRowBytes)
                                            
                                            let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
                                            
                                            let histogramMax = histogramBin.max()
                                            
                                            let index = histogramBin.firstIndex(of: histogramMax!)
                                            
                                            var histogramCounter = index!
                                            
                                            let bottomTenPercent = histogramMax!/10
                                            
                                            while((histogramCounter > 1) && histogramBin[histogramCounter] >= bottomTenPercent){
                                        
                                                    histogramCounter -= 1
                                                
                                                if (histogramCounter == 0) {
                                                    
                                                    break
                                                }
                                            
                                            }
                                            
                                           // histogramZeroLevel = 0.0
                                            
        //                                    //calculate the 0 level of the histogram
        //                                    for i in stride(from: 3, to: 22, by: 1){
        //
        //                                        histogramZeroLevel += Double(histogramBin[i])
        //
        //                                    }
        //
        //                                    histogramZeroLevel /= Double(20.0)
        //
        //
        //
        //                                    cutoff = histogramZeroLevel*histogramAboveBackground
        //
        //                                    var histogramCounter = 3
        //
        //                                    while(histogramBin[histogramCounter] < UInt(cutoff)){
        //
        //                                        histogramCounter += 1
        //
        //                                    }
            
                                            redMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
                                                
        //                                    var rawEqualizedvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToEqualizedRedFloats.baseAddress, height: vImagePixelCount(imageHeight), width: vImagePixelCount(imageWidth), rowBytes: sourceRowBytes)
                                            
                                                
                                                
                                                
                                            
                                                
                                        
                                            
                                        }
                                        
                                        
                                        
                                        redStretchedImage = vDSP.add(-redMinimum, redImage)
                                       
                                        //redImage = vDSP.multiply(1.0/(0.75-redMinimum), redStretchedImage)
                                        
                                        //redImage = vDSP.clip(redImage, to: 0.0...1.0)
                                       //come back to this
                                        //redImage = vDSP.add(-redMinimum, redImage)
        //                                redImage = vDSP.add((1.0/Float(histogramcount)*600), redImage)
                                    
                                        
                                        
                                        //Read in color correction parameters
                                        var ga = UserDefaults.standard.float(forKey: "color correction green a")
                                        var gb = UserDefaults.standard.float(forKey: "color correction green b")
                                        var ba = UserDefaults.standard.float(forKey: "color correction blue a")
                                        var bb = UserDefaults.standard.float(forKey: "color correction blue b")
                                        var ra = UserDefaults.standard.float(forKey: "color correction red a")
                                        var rb = UserDefaults.standard.float(forKey: "color correction red b")
                                        
                                        
                                        //Apply the aX+b transformation
                                        //Check b values so they don't make data negative
                                        if (-1*rb > redMinimum) { rb = 1*redMinimum}
                                        if (-1*gb > greenMinimum) { gb = 1*greenMinimum}
                                        if (-1*bb > blueMinimum) { bb = 1*blueMinimum}
                                        
                                        
                                        redImage = vDSP.multiply(ra, redImage)
                                        redImage = vDSP.add(rb, redImage)
                                        redImage = vDSP.clip(redImage, to: 0.0...1.0)
                                        
                                        blueImage = vDSP.multiply(ba, blueImage)
                                        blueImage = vDSP.add(bb, blueImage)
                                        blueImage = vDSP.clip(blueImage, to: 0.0...1.0)
                                        
                                        greenImage = vDSP.multiply(ga, greenImage)
                                        greenImage = vDSP.add(gb, greenImage)
                                        greenImage = vDSP.clip(greenImage, to: 0.0...1.0)
                                        
                                        //redImage = vDSP.add(0.0, redEqualizedImage)
                                        
                                        
                                        histogramAboveBackground = 10.0
                                        cutoff = 0.0
                                        
                                        
                                        //Luminance Image
                                        
                                        //grayValue = 0.222*red + 0.707*green + 0.071*blue.
                                        
                                        luminanceMinimum = 0.0
                                        
                                        var gray = vDSP.add(multiplication: (a: redImage, b: Float(0.222)), multiplication: (c: greenImage, d: Float(0.707)))
                                        
                                        
                                        luminanceImage = vDSP.add(multiplication: (a: blueImage, b: Float(0.071)), gray)
                                        
                                        
                                        luminanceImage.withUnsafeMutableBufferPointer {pointerToLuminanceFloats in
                                                                                
                                            let sourceRowBytes :Int = Int(imageWidthLocal) * MemoryLayout<Float>.size
                                            var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToLuminanceFloats.baseAddress, height: vImagePixelCount(imageHeightLocal), width: vImagePixelCount(imageWidthLocal), rowBytes: sourceRowBytes)
                                            
                                            let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
                                            
                                            let histogramMax = histogramBin.max()
                                            
                                            var index = histogramBin.firstIndex(of: histogramMax!)
                                            if (index == 0) { index = 1 }
                                                    
                                            var histogramCounter = index!
                                            
                                            let bottomTenPercent = histogramMax!/10
                                            
                                            while((histogramCounter > 1) && histogramBin[histogramCounter] >= bottomTenPercent){
                                        
                                                    histogramCounter -= 1
                                            
                                            }
                                            
                                           // histogramZeroLevel = 0.0
                                            
        //                                    //calculate the 0 level of the histogram
        //                                    for i in stride(from: 3, to: 22, by: 1){
        //
        //                                        histogramZeroLevel += Double(histogramBin[i])
        //
        //                                    }
        //
        //                                    histogramZeroLevel /= Double(20.0)
        //
        //
        //
        //                                    cutoff = histogramZeroLevel*histogramAboveBackground
        //
        //                                    var histogramCounter = 3
        //
        //                                    while(histogramBin[histogramCounter] < UInt(cutoff)){
        //
        //                                        histogramCounter += 1
        //
        //                                    }
            
                                            luminanceMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
                                                
        //                                    var rawEqualizedvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToEqualizedRedFloats.baseAddress, height: vImagePixelCount(imageHeight), width: vImagePixelCount(imageWidth), rowBytes: sourceRowBytes)
                                            
                                                
                                                
                                                
                                            
                                                
                                        
                                            
                                        }
                                        
                                        
                                        
                                        luminanceStretchedImage = vDSP.add(-luminanceMinimum, luminanceImage)
                                        
                                        //luminanceImage = vDSP.multiply(1.0/(0.75-luminanceMinimum), luminanceStretchedImage)
                                        
                                        luminanceImage = vDSP.clip(luminanceImage, to: 0.0...1.0)
                                        
                                        
                                        
                                        

                                        
                                        
        //                                luminanceImage.withUnsafeMutableBufferPointer {pointerToLuminanceFloats in
        //
        //                                    let sourceRowBytes :Int = Int(imageWidth) * MemoryLayout<Float>.size
        //                                    var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToLuminanceFloats.baseAddress, height: vImagePixelCount(imageHeight), width: vImagePixelCount(imageWidth), rowBytes: sourceRowBytes)
        //
        //                                    let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
        //
        //                                    histogramZeroLevel = 0.0
        //                                    cutoff = 0.0
        //
        //                                    //calculate the 0 level of the histogram
        //                                    for i in stride(from: 3, to: 22, by: 1){
        //
        //                                        histogramZeroLevel += Double(histogramBin[i])
        //
        //                                    }
        //
        //                                    histogramZeroLevel /= Double(20.0)
        //
        //
        //
        //                                    cutoff = histogramZeroLevel*histogramAboveBackground
        //
        //                                    var histogramCounter = 3
        //
        //                                    while(histogramBin[histogramCounter] < UInt(cutoff)){
        //
        //                                        histogramCounter += 1
        //
        //                                    }
        //
        //                                    luminanceMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
        //
        //
        //                                }
        //
        //                                luminanceImage = vDSP.add(-luminanceMinimum, luminanceImage)
        //
                                        
                                        var floatData :[FITSByte_F] = greenImage.bigEndian

                                        var myPrimaryHDU = PrimaryHDU(width: imageWidthLocal, height: imageHeightLocal, vectors: floatData)

                                        var file = FitsFile(prime: myPrimaryHDU)

                                        var filePath = URL(fileURLWithPath: NSHomeDirectory())

        //                                let filePath = selectedFile.deletingLastPathComponent()
        //
                                        var newFileURLString = filePath.absoluteString + "/Pictures/Green" + selectedFile.lastPathComponent



                                        var url = URL(string: newFileURLString)
                                        print(url)

                                        file.write(to: url!, onError: { error in
                                            print(error)
                                        }) {
                                            // file written

                                            print("File written")
                                        }
                                        
                                        
                                        floatData = redImage.bigEndian

                                        myPrimaryHDU = PrimaryHDU(width: imageWidthLocal, height: imageHeightLocal, vectors: floatData)

                                        file = FitsFile(prime: myPrimaryHDU)

                                        filePath = URL(fileURLWithPath: NSHomeDirectory())

        //                                let filePath = selectedFile.deletingLastPathComponent()
        //
                                        newFileURLString = filePath.absoluteString + "/Pictures/Red" + selectedFile.lastPathComponent



                                        url = URL(string: newFileURLString)
                                        print(url)

                                        file.write(to: url!, onError: { error in
                                            print(error)
                                        }) {
                                            // file written

                                            print("File written")
                                        }
                                        
                                        
                                        floatData = blueImage.bigEndian

                                        myPrimaryHDU = PrimaryHDU(width: imageWidthLocal, height: imageHeightLocal, vectors: floatData)

                                        file = FitsFile(prime: myPrimaryHDU)

                                        filePath = URL(fileURLWithPath: NSHomeDirectory())

        //                                let filePath = selectedFile.deletingLastPathComponent()
        //
                                        newFileURLString = filePath.absoluteString + "/Pictures/Blue" + selectedFile.lastPathComponent



                                        url = URL(string: newFileURLString)
                                        print(url)

                                        file.write(to: url!, onError: { error in
                                            print(error)
                                        }) {
                                            // file written

                                            print("File written")
                                        }
                                        
                                        floatData = luminanceImage.bigEndian

                                        myPrimaryHDU = PrimaryHDU(width: imageWidthLocal, height: imageHeightLocal, vectors: floatData)

                                        file = FitsFile(prime: myPrimaryHDU)

                                        filePath = URL(fileURLWithPath: NSHomeDirectory())

        //                                let filePath = selectedFile.deletingLastPathComponent()
        //
                                        newFileURLString = filePath.absoluteString + "/Pictures/Luminance" + selectedFile.lastPathComponent



                                        url = URL(string: newFileURLString)
                                        print(url)

                                        file.write(to: url!, onError: { error in
                                            print(error)
                                        }) {
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
        else {
            
            print("I don't know how to color convert this image.")
        }
        
        
        
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


struct ExtractColor_Previews: PreviewProvider {
    static var previews: some View {
        ExtractColor()
    }
}
