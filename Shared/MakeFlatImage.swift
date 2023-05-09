//
//  MakeColorImage.swift
//  MakeColorImage
//
//  Created by Jeff_Terry on 11/10/21.
//

import SwiftUI
import UniformTypeIdentifiers
import FITS
import FITSKit
import Accelerate

struct MakeFlatImage: View {
    
    @EnvironmentObject var listOfDocuments: DocumentList
    
    @FocusedBinding(\.document) var document
    
    @State var scale: CGFloat = 1.0
    
    @State var dataFloat :DocumentBinding? = nil
    @State var dataWidth :UInt? = nil
    @State var dataHeight :UInt? = nil
    
    @State var luminanceImage :DocumentBinding? = nil
    @State var luminanceWidth :UInt? = nil
    @State var luminanceHeight :UInt? = nil

    @State var redImage :DocumentBinding? = nil
    @State var redWidth :UInt? = nil
    @State var redHeight :UInt? = nil
    
    @State var blueImage :DocumentBinding? = nil
    @State var blueWidth :UInt? = nil
    @State var blueHeight :UInt? = nil
    
    @State var greenImage :DocumentBinding? = nil
    @State var greenWidth :UInt? = nil
    @State var greenHeight :UInt? = nil
    
    
    @State var selectedLuminanceImage = ""
    @State var selectedRedImage = ""
    @State var selectedGreenImage = ""
    @State var selectedBlueImage = ""
    
    
    @State var imageArray :[String] = [
    "Empty"]
//    @State var redImageArray :[String] = [
//    "Empty"]
//    @State var blueImageArray :[String] = [
//    "Empty"]
//    @State var greenImageArray :[String] = [
//    "Empty"]
    
    @State var colorImage :CGImage?
    
    var body: some View {
       
        
        VStack{
            Button(action: {
                
                PopulateImageField()
                colorImage = nil
                
                
            }, label: {
                Text("Populate Images")
            })
            //.disabled(document == nil)
            
            
            Spacer()
            
            HStack{
                
                Picker("Select Luminance Image", selection: $selectedLuminanceImage) {
                    ForEach($imageArray.wrappedValue, id: \.self) {
                        Text($0)
                    }
                }
                /*.onReceive([self.selectedImage].publisher.first()) { value in
                 self.doSomethingWith(value: value)
                 }*/
            }
            Spacer()
            
            HStack{
                
                Picker("Select Red Image", selection: $selectedRedImage) {
                    ForEach($imageArray.wrappedValue, id: \.self) {
                        Text($0)
                    }
                }
            }
            Spacer()
            
            HStack{
                
                Picker("Select Green Image", selection: $selectedGreenImage) {
                    ForEach($imageArray.wrappedValue, id: \.self) {
                        Text($0)
                    }
                }
            }
            
            Spacer()
            
            HStack{
                
                Picker("Select Blue Image", selection: $selectedBlueImage) {
                    ForEach($imageArray.wrappedValue, id: \.self) {
                        Text($0)
                    }
                }
            }
            
            Spacer()
            
            
            
            
            
        }
            
            
        
        VStack{
            
            //is setting the selected image files to be the names for each corresponding variable (I think?)
            Button(action: {makeTheColorImage(nameOfLuminanceDocument: selectedLuminanceImage, nameOfRedDocument: selectedRedImage, nameOfGreenDocument: selectedGreenImage, nameOfBlueDocument: selectedBlueImage)}, label: {
                        Text("Make The Color Image")
                    })
            
            Button(action:{if (colorImage != nil) {exportPNG(withImage: colorImage!)}}, label: {Text("Save PNG")})
        }
        
        VStack{
            //rawImage?.resizable().scaledToFit()
            if (colorImage != nil){
                    Image((colorImage!), scale: scale, label: Text("Raw")).resizable()
                        .scaleEffect(scale)
                        .aspectRatio(contentMode: .fit)
                        .gesture(MagnificationGesture()
                                    .onChanged { value in
                                        self.scale = value.magnitude
                                    }
                                )
                }
        }
        
    }
    
    func PopulateImageField(){
        
        imageArray.removeAll()
        
        imageArray.append(contentsOf: listOfDocuments.documentName)
        
        let starDocument = listOfDocuments.documentList[0]
        
        print(starDocument.imageHeight)
        
        let imageHeight = starDocument.imageHeight.wrappedValue
        
        print(imageHeight)
        
        print("Finding Stars")
        print(document)
        
    }
    
    func makeTheColorImage(nameOfLuminanceDocument: String, nameOfRedDocument: String, nameOfGreenDocument: String, nameOfBlueDocument: String){
        
        if let index = listOfDocuments.documentName.firstIndex(of: nameOfLuminanceDocument) {
            
            // Get the Address of the Selected Document
               luminanceImage = listOfDocuments.documentList[index]
               
               luminanceWidth =  listOfDocuments.documentList[index].imageWidth.wrappedValue
               
               luminanceHeight = listOfDocuments.documentList[index].imageHeight.wrappedValue
            }
    
        //Get the floating point array of image values from the selected Document
        var luminanceFloat = luminanceImage!.wrappedValue.ImageInfo!.5
        //let luminanceFloat = luminanceImage!.wrappedValue.rawFloatData
        
        var luminanceMinimum :Float = 100000.0
        
        
        luminanceFloat.withUnsafeMutableBufferPointer {pointerToLuminanceFloats in
        
            let sourceRowBytes :Int = Int(luminanceWidth!) * MemoryLayout<Float>.size
            let histogramcount :UInt32 = 4096
            var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToLuminanceFloats.baseAddress, height: vImagePixelCount(luminanceHeight!), width: vImagePixelCount(luminanceWidth!), rowBytes: sourceRowBytes)
            
            let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramcount)
            
            var shortHistogram :[UInt] = []
            
            for counter in stride(from: 1, to: histogramBin.count, by: 1){
                
                shortHistogram.append(histogramBin[counter])
            }
            
            
            let histogramMax = shortHistogram.max()
            
            let index = histogramBin.firstIndex(of: histogramMax!)
            
            var histogramCounter = index!
            
            while(histogramBin[histogramCounter] >= histogramMax!/10) && (histogramCounter >= 1){
        
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
            luminanceMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
        
            
        }
        
        var luminanceStretchedImage :[Float] = Array(repeating: 0.0, count: Int(luminanceWidth!*luminanceHeight!))

        
        //luminanceStretchedImage = vDSP.add(-luminanceMinimum, luminanceFloat)
        //luminanceFloat = vDSP.multiply(1.0/(1.10-luminanceMinimum), luminanceStretchedImage)
        //luminanceFloat = vDSP.clip(luminanceFloat, to: 0.0...1.0)
        
        
        
        
        
        if let index = listOfDocuments.documentName.firstIndex(of: nameOfRedDocument) {
            
            // Get the Address of the Selected Document
               redImage = listOfDocuments.documentList[index]
               
               redWidth =  listOfDocuments.documentList[index].imageWidth.wrappedValue
               
               redHeight = listOfDocuments.documentList[index].imageHeight.wrappedValue
            }
    
        //Get the floating point array of image values from the selected Document
        let redFloat = redImage!.wrappedValue.rawFloatData
        
        if let index = listOfDocuments.documentName.firstIndex(of: nameOfGreenDocument) {
            
            // Get the Address of the Selected Document
               greenImage = listOfDocuments.documentList[index]
               
               greenWidth =  listOfDocuments.documentList[index].imageWidth.wrappedValue
               
               greenHeight = listOfDocuments.documentList[index].imageHeight.wrappedValue
            }
    
        //Get the floating point array of image values from the selected Document
        let greenFloat = greenImage!.wrappedValue.rawFloatData
        
        if let index = listOfDocuments.documentName.firstIndex(of: nameOfBlueDocument) {
            
            // Get the Address of the Selected Document
               blueImage = listOfDocuments.documentList[index]
               
               blueWidth =  listOfDocuments.documentList[index].imageWidth.wrappedValue
               
               blueHeight = listOfDocuments.documentList[index].imageHeight.wrappedValue
            }
    
        //Get the floating point array of image values from the selected Document
        let blueFloat = blueImage!.wrappedValue.rawFloatData
        
        
        
        
        
        
        
        
        
        
        
        
        // ie, if all of the images have the same width and height
        if ( ((luminanceWidth == redWidth) && (luminanceWidth == greenWidth) && (luminanceWidth == blueWidth)) && ((luminanceHeight == redHeight) && (luminanceHeight == greenHeight) && (luminanceHeight == blueHeight) ) ){
            //implement whitebalance here
            
            
            
            
            
            
            
            
            
            //come back to this
            //let imageRedFloat = vDSP.multiply(luminanceFloat, vDSP.divide(redFloat, greenFloat))
            //let imageGreenFloat = vDSP.multiply(luminanceFloat, vDSP.divide(greenFloat, greenFloat))
            //let imageBlueFloat = vDSP.multiply(luminanceFloat, vDSP.divide(blueFloat, greenFloat))
            
            let imageRedFloat = redFloat
            let imageGreenFloat = greenFloat
            let imageBlueFloat = blueFloat
            
//            let temp = vDSP.add(redFloat, greenFloat)
//            let sum = vDSP.add(temp, blueFloat)
//
//            let divisor = vDSP.divide(sum, 3.0)
//
//            let imageRedFloat = vDSP.multiply(luminanceFloat, vDSP.divide(redFloat, divisor))
//            let imageGreenFloat = vDSP.multiply(luminanceFloat, vDSP.divide(greenFloat, divisor))
//            let imageBlueFloat = vDSP.multiply(luminanceFloat, vDSP.divide(blueFloat, divisor))
            
            
            
            
            
            
            
            
            var rgbFloat :[Float] = []
            
            for index in stride(from: 0, to: imageRedFloat.count, by: 1){
                
                
                rgbFloat.append(imageRedFloat[index])
                rgbFloat.append(imageGreenFloat[index])
                rgbFloat.append(imageBlueFloat[index])
                
            }
            
            let rowBytes :Int = Int(luminanceWidth!) * 3 * MemoryLayout<Float>.size
            
            colorImage = returningColorCGImage(data: rgbFloat, width: Int(luminanceWidth!), height: Int(luminanceHeight!), rowBytes: rowBytes)
            
        }
        
        
        
    }
    
    

}


struct MakeFlatImage_Previews: PreviewProvider {
    static var previews: some View {
        MakeColorImage()
    }
}
