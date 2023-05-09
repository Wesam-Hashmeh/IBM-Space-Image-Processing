//
//  MakeFlatView.swift
//  MakeFlatView
//
//  Created by Jeff_Terry on 12/23/21.
//

import SwiftUI
import UniformTypeIdentifiers
import FITS
import FITSKit
import Accelerate


struct MakeFlatView: View {
    @EnvironmentObject var listOfDocuments: DocumentList
    
    @FocusedBinding(\.document) var document
    
    @State var dataFloat :DocumentBinding? = nil
    @State var dataWidth :UInt? = nil
    @State var dataHeight :UInt? = nil
    
    @State var selectingDarkFile: Bool = false
    @State var selectingFilesToAdd: Bool = false
    
    @State var selectingFilesToSave: Bool = false
    @State var selectingFilesToColorConvert: Bool = false
    
    @State var colorType = "RGGB"
    
    @State var bayerOrientationArray = ["RGGB", "BGGR"]
    
    @State var rawDataFromFITSFile : ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)?
    
    @State var imageHeight = 0
    @State var imageWidth = 0
    
    @State var darkFloatArray :[Float] = []
    
    @State var darkDocument = FITSDocumentDocument(text: "Hello, world!")
    
    @State var allowMultipleDirectories = false
    @State var showingAlert = false
    
    @State var greenMultiply :Float = 1.0
    @State var redMultiply :Float = 1.0
    @State var blueMultiply :Float = 1.0
    
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
        
        var rowRemainder = 0
        var columnRemainder = 0
        
        for item in imageArray
                
        {
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
                    
                    var greenMinimum :Float = 100000.0
                    var redMinimum :Float = 100000.0
                    var blueMinimum :Float = 100000.0
                    var luminanceMinimum :Float = 100000.0
                    
                    var greenImage :[Float] = Array(repeating: 0.0, count: imageWidth*imageHeight)
                    var greenStretchedImage :[Float] = Array(repeating: 0.0, count: imageWidth*imageHeight)
                    
                    var redImage :[Float] = Array(repeating: 0.0, count: imageWidth*imageHeight)
                    var redStretchedImage :[Float] = Array(repeating: 0.0, count: imageWidth*imageHeight)
                    
                    var blueImage :[Float] = Array(repeating: 0.0, count: imageWidth*imageHeight)
                    var blueStretchedImage :[Float] = Array(repeating: 0.0, count: imageWidth*imageHeight)
                    
                    var luminanceImage :[Float] = Array(repeating: 0.0, count: imageWidth*imageHeight)
                    var luminanceStretchedImage :[Float] = Array(repeating: 0.0, count: imageWidth*imageHeight)
                    
                    
                    if colorType ==
                        "RGGB" {
                        
                        
                        /*   Color Conversion   */
                        
                        // start in Second Row and Second Column
                        
                        for row in stride(from: 1, to: imageHeight-1, by: 1){
                            
                            for column in stride(from: 1, to: imageWidth-1, by: 1){
                                
                                //Calculate color position
                                
                                rowRemainder = row % 2
                                columnRemainder = column % 2
                                
                                if (rowRemainder == 0){
                                    
                                    if (columnRemainder == 1){
                                        
                                        //rowRemainder == 0
                                        //columnRemainder == 1
                                        
                                        //It is green already
                                        greenImage[column + row * imageWidth] = (floatDataFromFITSFile[column + row * imageWidth])
                                        
                                        //R(column,row) = (D(column-1, row) + D(column+1, row))/2
                                        redImage[column + row * imageWidth] = (0.5*(floatDataFromFITSFile[column + 1 + (row) * imageWidth] + floatDataFromFITSFile[column - 1 + (row) * imageWidth]))
                                        
                                        //  B(column, row) = ( D(column, row-1) + D(column, row+1))/2
                                        blueImage[column + row * imageWidth] = (0.5*(floatDataFromFITSFile[column + (row-1) * imageWidth] + floatDataFromFITSFile[column + (row+1) * imageWidth]))
                                         
                                    }
                                    else{
                                        
                                        //rowRemainder == 0
                                        //columnRemainder == 0
                                        
                                        //G(column,row) = ( G(column-1, row) + G( column+1, row)  +G(column, row+1) + G (column, row - 1) )/4
                                        greenImage[column + row * imageWidth] = (0.25*(floatDataFromFITSFile[column + (row-1) * imageWidth] + floatDataFromFITSFile[column + (row+1) * imageWidth] + floatDataFromFITSFile[(column+1) + row * imageWidth] + floatDataFromFITSFile[(column-1) + row * imageWidth]))
                                        
                                        //It is red already
                                        redImage[column + row * imageWidth] = (floatDataFromFITSFile[column + row * imageWidth])
                                        
                                        //  B(column, row) = ( D(column-1, row-1) + D(column+1, row-1) + D(column-1, row+1) +  D(column+1, row+1) )/4
                                        blueImage[column + row * imageWidth] = (0.25*(floatDataFromFITSFile[column - 1 + (row-1) * imageWidth] + floatDataFromFITSFile[column + 1 + (row+1) * imageWidth] + floatDataFromFITSFile[(column-1) + (row+1) * imageWidth] + floatDataFromFITSFile[(column+1) + (row+1) * imageWidth]))
                                    }
                                    
                                }
                                else{
                                    
                                    if(columnRemainder == 1){
                                        
                                        //rowRemainder == 1
                                        //columnRemainder == 1
                                        
                                        //G(column,row) = ( D(column-1, row) + D( column+1, row)  + D(column, row+1) + D(column, row - 1) )/4
                                        greenImage[column + row * imageWidth] = (0.25*(floatDataFromFITSFile[column - 1 + (row) * imageWidth] + floatDataFromFITSFile[column + 1 + (row) * imageWidth] + floatDataFromFITSFile[column + (row+1) * imageWidth] + floatDataFromFITSFile[column + (row-1) * imageWidth]))
                                        
                                        //  R(column, row) = ( D(column-1, row-1) + D(column+1, row-1) + D(column-1, row+1) +  D(column+1, row+1) )/4
                                        redImage[column + row * imageWidth] = (0.25*(floatDataFromFITSFile[column - 1 + (row-1) * imageWidth] + floatDataFromFITSFile[column + 1 + (row-1) * imageWidth] + floatDataFromFITSFile[column - 1 + (row+1) * imageWidth] + floatDataFromFITSFile[column + 1  + (row+1) * imageWidth]))
                                        
                                        // It is blue already
                                        blueImage[column + row * imageWidth] = (floatDataFromFITSFile[column + row * imageWidth])
                                        
                                    }
                                    else{
                                        
                                        
                                        //rowRemainder = 1
                                        //columnRemainder = 0
                                        
                                        
                                        //It is green already
                                        greenImage[column + row * imageWidth] = (floatDataFromFITSFile[column + row * imageWidth])
                                        
                                        
                                        //  R(column, row) = ( D(column, row-1) + D(column, row+1))/2
                                        redImage[column + row * imageWidth] = (0.5*(floatDataFromFITSFile[column + (row-1) * imageWidth] + floatDataFromFITSFile[column + (row+1) * imageWidth]))
                                        
                                        
                                        //B(column,row) = ( D(column-1, row) + D(column+1, row)  )/2
                                        blueImage[column + row * imageWidth] = (0.5*(floatDataFromFITSFile[column - 1 + (row) * imageWidth] + floatDataFromFITSFile[column + 1 + (row) * imageWidth]))

                                    }
                                    
                                }
                                
                                
                                if (greenMinimum > greenImage[column + row * imageWidth]) {
                                    greenMinimum = greenImage[column + row * imageWidth]
                                }
                                
                                if (redMinimum > redImage[column + row * imageWidth]) {
                                    redMinimum = redImage[column + row * imageWidth]
                                }
                                
                                if (blueMinimum > blueImage[column + row * imageWidth]) {
                                    blueMinimum = blueImage[column + row * imageWidth]
                                }
                            }
                            
                        }
                        
                        
                        
                        
                    }
                    else if colorType == "BGGR"{
                        
                        
                        /*   Color Conversion   */
                        
                        // Red and Blue are Swapped from Above
                        
                        // start in Second Row and Second Column
                        
                        for row in stride(from: 1, to: imageHeight-1, by: 1){
                            
                            for column in stride(from: 1, to: imageWidth-1, by: 1){
                                
                                //Calculate color position
                                rowRemainder = row % 2
                                columnRemainder = column % 2
                                
                                if (rowRemainder == 0){
                                    if (columnRemainder == 1){
                                        
                                        //rowRemainder == 0
                                        //columnRemainder == 1
                                        
                                        //It is green already
                                        greenImage[column + row * imageWidth] = (floatDataFromFITSFile[column + row * imageWidth])
                                        
                                        //B(column,row) = (D(column-1, row) + D(column+1, row))/2
                                        blueImage[column + row * imageWidth] = (0.5*(floatDataFromFITSFile[column + 1 + (row) * imageWidth] + floatDataFromFITSFile[column - 1 + (row) * imageWidth]))
                                        
                                        //  R(column, row) = ( D(column, row-1) + D(column, row+1))/2
                                        redImage[column + row * imageWidth] = (0.5*(floatDataFromFITSFile[column + (row-1) * imageWidth] + floatDataFromFITSFile[column + (row+1) * imageWidth]))
                                    }
                                    else{
                                        
                                        //rowRemainder == 0
                                        //columnRemainder == 0
                                        
                                        //G(column,row) = ( G(column-1, row) + G( column+1, row)  +G(column, row+1) + G (column, row - 1) )/4
                                        greenImage[column + row * imageWidth] = (0.25*(floatDataFromFITSFile[column + (row-1) * imageWidth] + floatDataFromFITSFile[column + (row+1) * imageWidth] + floatDataFromFITSFile[(column+1) + row * imageWidth] + floatDataFromFITSFile[(column-1) + row * imageWidth]))
                                        
                                        //It is blue already
                                        blueImage[column + row * imageWidth] = (floatDataFromFITSFile[column + row * imageWidth])
                                        
                                        //  R(column, row) = ( D(column-1, row-1) + D(column+1, row-1) + D(column-1, row+1) +  D(column+1, row+1) )/4
                                        redImage[column + row * imageWidth] = (0.25*(floatDataFromFITSFile[column - 1 + (row-1) * imageWidth] + floatDataFromFITSFile[column + 1 + (row+1) * imageWidth] + floatDataFromFITSFile[(column-1) + (row+1) * imageWidth] + floatDataFromFITSFile[(column+1) + (row+1) * imageWidth]))
                                    }
                                    
                                }
                                else{
                                    
                                    if(columnRemainder == 1){
                                        
                                        //rowRemainder == 1
                                        //columnRemainder == 1
                                        
                                        //G(column,row) = ( D(column-1, row) + D( column+1, row)  + D(column, row+1) + D(column, row - 1) )/4
                                        greenImage[column + row * imageWidth] = (0.25*(floatDataFromFITSFile[column - 1 + (row) * imageWidth] + floatDataFromFITSFile[column + 1 + (row) * imageWidth] + floatDataFromFITSFile[column + (row+1) * imageWidth] + floatDataFromFITSFile[column + (row-1) * imageWidth]))
                                        
                                        //  B(column, row) = ( D(column-1, row-1) + D(column+1, row-1) + D(column-1, row+1) +  D(column+1, row+1) )/4
                                        blueImage[column + row * imageWidth] = (0.25*(floatDataFromFITSFile[column - 1 + (row-1) * imageWidth] + floatDataFromFITSFile[column + 1 + (row-1) * imageWidth] + floatDataFromFITSFile[column - 1 + (row+1) * imageWidth] + floatDataFromFITSFile[column + 1  + (row+1) * imageWidth]))
                                        
                                        // It is red already
                                        redImage[column + row * imageWidth] = (floatDataFromFITSFile[column + row * imageWidth])
                                    }
                                    else{
                                        
                                        
                                        //rowRemainder = 1
                                        //columnRemainder = 0
                                        
                                        
                                        //It is green already
                                        greenImage[column + row * imageWidth] = (floatDataFromFITSFile[column + row * imageWidth])
                                        
                                        //  B(column, row) = ( D(column, row-1) + D(column, row+1))/2
                                        blueImage[column + row * imageWidth] = (0.5*(floatDataFromFITSFile[column + (row-1) * imageWidth] + floatDataFromFITSFile[column + (row+1) * imageWidth]))
                                        
                                        //R(column,row) = ( D(column-1, row) + D(column+1, row)  )/2
                                        redImage[column + row * imageWidth] = (0.5*(floatDataFromFITSFile[column - 1 + (row) * imageWidth] + floatDataFromFITSFile[column + 1 + (row) * imageWidth]))
                                        
                                    }
                                    
                                }
                                
                                if (greenMinimum > greenImage[column + row * imageWidth]) {
                                    greenMinimum = greenImage[column + row * imageWidth]
                                }
                                
                                if (redMinimum > redImage[column + row * imageWidth]) {
                                    redMinimum = redImage[column + row * imageWidth]
                                }
                                
                                if (blueMinimum > blueImage[column + row * imageWidth]) {
                                    blueMinimum = blueImage[column + row * imageWidth]
                                }
                                
                            }
                            
                        }
                        
                        
                    }
                    else {
                        
                        print("I don't know how to color convert this image.")
                    }
                    
                    // Setting values from 0-1, fix negative values to 0
                    //
                    //                                var greenMinFloat = vDSP.add(-(greenMinimum), greenImage)
                    //
                    //                                for index in stride(from: 0, to: greenImage.count, by: 1) {
                    //
                    //                                    if greenImage[index] < 0.0 {
                    //
                    //                                        greenImage[index] = 0.0
                    //                                    }
                    //
                    //                                }
                    //
                    //                                var redMinFloat = vDSP.add(-(redMinimum), redImage)
                    //
                    //                                for index in stride(from: 0, to: redImage.count, by: 1) {
                    //
                    //                                    if redImage[index] < 0.0 {
                    //
                    //                                        redImage[index] = 0.0
                    //                                    }
                    //
                    //                                }
                    //
                    //                                var blueMinFloat = vDSP.add(-(blueMinimum), blueImage)
                    //
                    //                                for index in stride(from: 0, to: blueImage.count, by: 1) {
                    //
                    //                                    if blueImage[index] < 0.0 {
                    //
                    //                                        blueImage[index] = 0.0
                    //                                    }
                    //
                    //                                }
                    //
                    //
                    //
                    //                                //greenImage = vDSP.multiply(greenMultiply, greenImage)
                    //                                //redImage = vDSP.multiply(redMultiply, redImage)
                    //                                //blueImage = vDSP.multiply(blueMultiply, blueImage)
                    
                    //
                    let histogramcount :UInt32 = 4096
                    var histogramZeroLevel = 0.0
                    var histogramAboveBackground = 20.0
                    var cutoff = 0.0
                    
                    //Green histogram points
                    var greenMax :Float = 1.0
                    var greenMaxIndex :Float = 1.0
                    var greenSD :Float = 0.0
                    
                    greenImage.withUnsafeMutableBufferPointer {
                        pointerToGreenFloats in
                        
                        let sourceRowBytes :Int = Int(imageWidth) * MemoryLayout<Float>.size
                        var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToGreenFloats.baseAddress, height: vImagePixelCount(imageHeight), width: vImagePixelCount(imageWidth), rowBytes: sourceRowBytes)
                        
                        let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
                        
                        
                        let histogramMax = histogramBin.max()
                        
                        let index = histogramBin.firstIndex(of: histogramMax!)
                        greenMaxIndex = Float(index!)
                        
                        //Converts from histogram index to actual pixel value
                        greenMax = Float(index!) / Float(histogramcount)
                        
                        var histogramCounter = index!
                        
                        while(histogramBin[histogramCounter] >= histogramMax!/10){
                            histogramCounter -= 1
                        }
                        
                        //Converts from histogram index to actual pixel value
                        greenMinimum = (Float(histogramCounter) / Float(histogramcount))
                        
                        
                        //Approximate Standard Deviation
                        
                        //Find begining of graph
                        var min = 0
                        for i in 1..<Int(histogramBin.count) {
                            if(histogramBin[i] > 15){
                                min = i
                                break
                            }
                        }
                        
                        //Find end of graph
                        var max = 0
                        for i in min..<Int(histogramBin.count) {
                            if(histogramBin[i] == 0){
                                max = i
                                break
                            }
                        }
                        
                        //Entire graph is about 6 standard deviations
                        greenSD = Float(max-min) / 6
                        
                    }
                    
                    
                    
                    //
                    //
                    //
                    ////                                    //calculate the 0 level of the histogram
                    ////                                    for i in stride(from: 3, to: 22, by: 1){
                    ////
                    ////                                        histogramZeroLevel += Double(histogramBin[i])
                    ////
                    ////                                    }
                    ////
                    ////                                    histogramZeroLevel /= Double(20.0)
                    ////
                    ////
                    ////
                    ////                                    cutoff = histogramZeroLevel*histogramAboveBackground
                    ////
                    ////                                    var histogramCounter = 3
                    ////
                    ////                                    while(histogramBin[histogramCounter] < UInt(cutoff)){
                    ////
                    ////                                        histogramCounter += 1
                    ////
                    ////                                    }
                    ////
                    ///
                    ///
                    ///
                    //  Creates stretched image (probably wrong)
                    //
                    //                                    greenMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
                    //
                    //
                    //                                }
                    //
                    //                                greenStretchedImage = vDSP.add(-greenMinimum, greenImage)
                    //
                    //                                greenImage = vDSP.multiply(1.0/(1.10-greenMinimum), greenStretchedImage)
                    //
                    //                                greenImage = vDSP.clip(greenImage, to: 0.0...1.0)
                    //
                    //
                    //
                    //                                //greenImage = vDSP.add(-greenMinimum, greenImage)
                    //
                    //                                cutoff = 0.0
                    //                                histogramAboveBackground = 75.0
                    
                    
                    //Blue histogram points
                    var blueMax :Float = 1.0
                    var blueMaxIndex :Float = 1.0
                    var blueSD :Float = 0.0
                    // blueImage = vDSP.multiply(0.77,blueImage)
                    //redImage = vDSP.multiply(2,redImage)
                    blueImage.withUnsafeMutableBufferPointer {pointerToBlueFloats in
                        
                        let sourceRowBytes :Int = Int(imageWidth) * MemoryLayout<Float>.size
                        var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToBlueFloats.baseAddress, height: vImagePixelCount(imageHeight), width: vImagePixelCount(imageWidth), rowBytes: sourceRowBytes)
                        
                        let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
                        
                        let histogramMax = histogramBin.max()
                        
                        let index = histogramBin.firstIndex(of: histogramMax!)
                        blueMaxIndex = Float(index!)
                        
                        //Convert from histogram point to actual pixel value
                        blueMax = Float(index!)*1.0/Float(histogramcount)
                        
                        
                        
                        var histogramCounter = index!
                        
                        while(histogramBin[histogramCounter] >= histogramMax!/10){
                            //
                            histogramCounter -= 1
                            //
                        }
                        
                        
                        //Approximate Standard Deviation
                        
                        //Find beginning of graph
                        var min = 0
                        for i in 1..<Int(histogramBin.count) {
                            if(histogramBin[i] > 15){ //lots of noise under 15
                                min = i
                                break
                            }
                        }
                        
                        //Find end of graph
                        var max = 0
                        for i in min..<Int(histogramBin.count) {
                            if(histogramBin[i] == 0){
                                max = i
                                break
                            }
                        }
                        
                        //Entire graph is about 6 standard deviations
                        blueSD = Float(max-min) / 6
                        
                        
                        
                        
                        
                        
                    }
                    
                    
                    
                    
                    
                    //                                blueImage = vDSP.clip(blueImage, to: 0.0...1.0)
                    //
                    //                                   // histogramZeroLevel = 0.0
                    //
                    ////                                    //calculate the 0 level of the histogram
                    ////                                    for i in stride(from: 3, to: 22, by: 1){
                    ////
                    ////                                        histogramZeroLevel += Double(histogramBin[i])
                    ////
                    ////                                    }
                    ////
                    ////                                    histogramZeroLevel /= Double(20.0)
                    ////
                    ////
                    ////
                    ////                                    cutoff = histogramZeroLevel*histogramAboveBackground
                    ////
                    ////                                    var histogramCounter = 3
                    ////
                    ////                                    while(histogramBin[histogramCounter] < UInt(cutoff)){
                    ////
                    ////                                        histogramCounter += 1
                    ////
                    ////                                    }
                    ////
                    ////                                    print("Blue", cutoff, histogramCounter)
                    //
                    //                                    blueMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
                    //
                    //                                    print("Blue minimum", blueMinimum)
                    //
                    //
                    //                                }
                    //
                    //                                blueStretchedImage = vDSP.add(-blueMinimum, blueImage)
                    //
                    //                                blueImage = vDSP.multiply(1.0/(1.0-blueMinimum), blueStretchedImage)
                    //
                    //                                blueImage = vDSP.clip(blueImage, to: 0.0...1.0)
                    //
                    //                                //blueImage = vDSP.add(-blueMinimum, blueImage)
                    //
                    //                                histogramAboveBackground = 0.0
                    //                                cutoff = 0.0
                    
                    
                    //Red histogram points
                    var redMax :Float = 1.0
                    var redMaxIndex :Float = 1.0
                    var redSD :Float = 0.0
                    
                    //
                    redImage.withUnsafeMutableBufferPointer {pointerToRedFloats in
                        
                        let sourceRowBytes :Int = Int(imageWidth) * MemoryLayout<Float>.size
                        var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToRedFloats.baseAddress, height: vImagePixelCount(imageHeight), width: vImagePixelCount(imageWidth), rowBytes: sourceRowBytes)
                        
                        let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
                        
                        let histogramMax = histogramBin.max()
                        
                        let index = histogramBin.firstIndex(of: histogramMax!)
                        redMaxIndex = Float(index!)
                        
                        //Converts from histogram index to actual pixel value
                        redMax = Float(index!) / Float(histogramcount)
                        
                        //Approximate Standard Deviation
                        
                        //Find the beginning of the graph
                        var min = 0
                        for i in 1..<Int(histogramBin.count) {
                            if(histogramBin[i] > 15){ //Lots of noise under 10
                                min = i
                                break
                            }
                        }
                        
                        //Find the end of the graph
                        var max = 0
                        for i in min..<Int(histogramBin.count) {
                            if(histogramBin[i] == 0){
                                max = i
                                break
                            }
                        }
                        
                        //Entire graph is about 6 standard deviations
                        redSD = Float(max-min) / 6
                        
                        
                        var histogramCounter = index!
                        while(histogramBin[histogramCounter] >= histogramMax!/10){
                            histogramCounter -= 1
                            if (histogramCounter == 0) {
                                break
                            }
                        }
                        
                        redMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
                    }
                    
                    
                    
                    
                    
                    //blueImage = vDSP.multiply(1.0/(1.0-blueMinimum), blueImage)
                    //redImage = vDSP.multiply(1.0/(0.75-redMinimum), redImage)
                    //greenImage = vDSP.multiply(1.0/(1.10-greenMinimum), greenImage)
                    
                    
                    
                    
                    //redImage = vDSP.clip(redImage, to: 0.0...1.0)
                    
                    //Don't know why this is here
                    //Based on clip that happens later, it clips anything less than 0.5
                    //Shifts colors depending on their max value. Trys shifting it to the center (0.5)
                    
                    //greenImage = vDSP.add(0.5-greenMax, greenImage)
                    //blueImage = vDSP.add(0.5-blueMax, blueImage)
                    //redImage = vDSP.add(0.5-redMax, redImage)
                    
                    
                    //Find the middle standard deviation
                    /*var midSD :Float = 0.0
                    if (redSD >= greenSD) {
                        if (redSD <= blueSD){
                            midSD = redSD
                        }
                        else{
                            midSD = blueSD
                        }
                    }
                    else {
                        if (greenSD >= blueSD){
                            midSD = blueSD
                        }
                        else{
                            midSD = greenSD
                        }
                    }*/
                    
                    var ga :Float = 0.0
                    var gb :Float = 0.0
                    var ba :Float = 0.0
                    var bb :Float = 0.0
                    var ra :Float = 0.0
                    var rb :Float = 0.0
                    
                    //Apply a guassian transformation
                    //Shift the mean and sd
                    //Shift to green histogram
                    
                    ga = sqrt(greenSD/greenSD)
                    gb = Float(greenMax) - (ga*Float(greenMax))
                    greenImage = vDSP.multiply(ga, greenImage)
                    greenImage = vDSP.add(gb, greenImage)
                    
                    ba = sqrt(greenSD/blueSD)
                    bb = Float(greenMax) - (ba*Float(blueMax))
                    blueImage = vDSP.multiply(ba, blueImage)
                    blueImage = vDSP.add(bb, blueImage)
                    
                    ra = sqrt(greenSD/redSD)
                    rb = Float(greenMax) - (ra*Float(redMax))
                    redImage = vDSP.multiply(ra, redImage)
                    redImage = vDSP.add(rb, redImage)
                    
                    
                    
                    // Store color correcting parameters
                    UserDefaults.standard.set(ga, forKey: "color correction green a")
                    UserDefaults.standard.set(gb, forKey: "color correction green b")
                    UserDefaults.standard.set(ba, forKey: "color correction blue a")
                    UserDefaults.standard.set(bb, forKey: "color correction blue b")
                    UserDefaults.standard.set(ra, forKey: "color correction red a")
                    UserDefaults.standard.set(rb, forKey: "color correction red b")
                    
                    //redImage = vDSP.multiply(1.1,redImage)
                    
                    //Calculating filter sensitivities (can be improved)
                    //greenMultiply = greenMax/greenMax
                    //blueMultiply = greenMax/blueMax
                    //redMultiply = greenMax/redMax
                    
                    
                    
                    //come back to this
                    //greenImage = vDSP.multiply(greenMultiply, greenImage)
                    //redImage = vDSP.multiply(redMultiply, redImage)
                    //blueImage = vDSP.multiply(blueMultiply, blueImage)
                    
                    
                    
                    
                    
                    
                    
                    
                    
                    //
                    //                                   // histogramZeroLevel = 0.0
                    //
                    ////                                    //calculate the 0 level of the histogram
                    ////                                    for i in stride(from: 3, to: 22, by: 1){
                    ////
                    ////                                        histogramZeroLevel += Double(histogramBin[i])
                    ////
                    ////                                    }
                    ////
                    ////                                    histogramZeroLevel /= Double(20.0)
                    ////
                    ////
                    ////
                    ////                                    cutoff = histogramZeroLevel*histogramAboveBackground
                    ////
                    ////                                    var histogramCounter = 3
                    ////
                    ////                                    while(histogramBin[histogramCounter] < UInt(cutoff)){
                    ////
                    ////                                        histogramCounter += 1
                    ////
                    ////                                    }
                    //
                    //                                    redMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
                    //
                    ////                                    var rawEqualizedvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToEqualizedRedFloats.baseAddress, height: vImagePixelCount(imageHeight), width: vImagePixelCount(imageWidth), rowBytes: sourceRowBytes)
                    //
                    //
                    //
                    //
                    //
                    //
                    //
                    //
                    //                                }
                    //
                    //
                    //
                    //                                redStretchedImage = vDSP.add(-redMinimum, redImage)
                    //
                    //                                redImage = vDSP.multiply(1.0/(0.75-redMinimum), redStretchedImage)
                    //
                    //                                redImage = vDSP.clip(redImage, to: 0.0...1.0)
                    //
                    //                               // redImage = vDSP.add(-redMinimum, redImage)
                    ////                                redImage = vDSP.add((1.0/Float(histogramcount)*600), redImage)
                    //
                    //
                    //                                //redImage = vDSP.add(0.0, redEqualizedImage)
                    //
                    
                    //                                histogramAboveBackground = 10.0
                    //                                cutoff = 0.0
                    
                    
                    redImage = vDSP.clip(redImage, to: 0.0...1.0)
                    blueImage = vDSP.clip(blueImage, to: 0.0...1.0)
                    greenImage = vDSP.clip(greenImage, to: 0.0...1.0)
                    
                    
                    
                    //Luminance Image
                    
                    //grayValue = 0.222*red + 0.707*green + 0.071*blue.
                    
                    luminanceMinimum = 0.0
                    
                    //Creates luminance array by combining red, green, and blue
                    let gray = vDSP.add(multiplication: (a: redImage, b: Float(0.222)), multiplication: (c: greenImage, d: Float(0.707)))
                    //let gray = vDSP.add(multiplication: (a: redImage, b: Float(1.0)), //multiplication: (c: greenImage, d: Float(1.0)))
                    luminanceImage = vDSP.add(multiplication: (a: blueImage, b: Float(0.071)), gray)
                    //luminanceImage = vDSP.add(multiplication: (a: blueImage, b: Float(1.0)), //gray)
                    
                    var luminanceMax :Float = 1.0
                    luminanceImage.withUnsafeMutableBufferPointer {pointerToLuminanceFloats in
                        
                        let sourceRowBytes :Int = Int(imageWidth) * MemoryLayout<Float>.size
                        var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToLuminanceFloats.baseAddress, height: vImagePixelCount(imageHeight), width: vImagePixelCount(imageWidth), rowBytes: sourceRowBytes)
                        
                        let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
                        
                        let histogramMax = histogramBin.max()
                        
                        let index = histogramBin.firstIndex(of: histogramMax!)
                        
                        luminanceMax = Float(index!)*1.0/Float(histogramcount)
                        
                        var histogramCounter = index!
                        let bottomTenPercent = histogramMax!/10
                        while(histogramBin[histogramCounter] >= bottomTenPercent){
                            
                            histogramCounter -= 1
                            
                        }
                    }
                    
                    
                    //
                    //                                   // histogramZeroLevel = 0.0
                    //
                    ////                                    //calculate the 0 level of the histogram
                    ////                                    for i in stride(from: 3, to: 22, by: 1){
                    ////
                    ////                                        histogramZeroLevel += Double(histogramBin[i])
                    ////
                    ////                                    }
                    ////
                    ////                                    histogramZeroLevel /= Double(20.0)
                    ////
                    ////
                    ////
                    ////                                    cutoff = histogramZeroLevel*histogramAboveBackground
                    ////
                    ////                                    var histogramCounter = 3
                    ////
                    ////                                    while(histogramBin[histogramCounter] < UInt(cutoff)){
                    ////
                    ////                                        histogramCounter += 1
                    ////
                    ////                                    }
                    //
                    //                                    luminanceMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
                    //
                    ////                                    var rawEqualizedvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToEqualizedRedFloats.baseAddress, height: vImagePixelCount(imageHeight), width: vImagePixelCount(imageWidth), rowBytes: sourceRowBytes)
                    //
                    //
                    //
                    //
                    //
                    //
                    //
                    //
                    //                                }
                    //
                    //
                    //
                    //luminanceStretchedImage = vDSP.add(-luminanceMinimum, luminanceImage)
                    
                    //luminanceImage = vDSP.multiply(1.0/(0.75-luminanceMinimum), luminanceImage)
                    luminanceImage = vDSP.add(0.5-luminanceMax,luminanceImage)
                    luminanceImage = vDSP.clip(luminanceImage, to: 0.0...1.0)
                    
                    
                    
                    
                    /*
                     //Another attempt at figuring out histogram
                     //Probably junk
                     
                     luminanceImage.withUnsafeMutableBufferPointer {pointerToLuminanceFloats in
                     
                     let sourceRowBytes :Int = Int(imageWidth) * MemoryLayout<Float>.size
                     var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToLuminanceFloats.baseAddress, height: vImagePixelCount(imageHeight), width: vImagePixelCount(imageWidth), rowBytes: sourceRowBytes)
                     
                     let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
                     
                     histogramZeroLevel = 0.0
                     cutoff = 0.0
                     
                     //calculate the 0 level of the histogram
                     for i in stride(from: 3, to: 22, by: 1){
                     
                     histogramZeroLevel += Double(histogramBin[i])
                     
                     }
                     
                     histogramZeroLevel /= Double(20.0)
                     
                     
                     
                     cutoff = histogramZeroLevel*histogramAboveBackground
                     
                     var histogramCounter = 3
                     
                     while(histogramBin[histogramCounter] < UInt(cutoff)){
                     
                     histogramCounter += 1
                     
                     }
                     
                     luminanceMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
                     
                     
                     }
                     
                     luminanceImage = vDSP.add(-luminanceMinimum, luminanceImage)
                     */
                    
                    
                    // Generates pictures
                    
                    var floatData :[FITSByte_F] = greenImage.bigEndian
                    
                    var myPrimaryHDU = PrimaryHDU(width: imageWidth, height: imageHeight, vectors: floatData)
                    
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
                    
                    myPrimaryHDU = PrimaryHDU(width: imageWidth, height: imageHeight, vectors: floatData)
                    
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
                    
                    myPrimaryHDU = PrimaryHDU(width: imageWidth, height: imageHeight, vectors: floatData)
                    
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
                    
                    myPrimaryHDU = PrimaryHDU(width: imageWidth, height: imageHeight, vectors: floatData)
                    
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


struct MakeFlatView_Previews: PreviewProvider {
    static var previews: some View {
        MakeDarkView()
    }
}
