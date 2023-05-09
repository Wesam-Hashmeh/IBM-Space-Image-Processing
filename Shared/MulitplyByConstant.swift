//
//  MulitplyByConstant.swift
//  FITSDocument
//
//  Created by Jeff Terry on 9/19/22.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import FITS
import FITSKit
import Accelerate

struct MultiplyByConstant: View {
    
    @EnvironmentObject var listOfDocuments: DocumentList
    
    @FocusedBinding(\.document) var document
    
    @State var scale: CGFloat = 1.0
    
    @State var dataFloat :DocumentBinding? = nil
    @State var dataWidth :UInt? = nil
    @State var dataHeight :UInt? = nil
    
    @State var luminanceImage :DocumentBinding? = nil
    @State var luminanceWidth :UInt? = nil
    @State var luminanceHeight :UInt? = nil
    
    @State var imageHeight = 0
    @State var imageWidth = 0
    
    @State var multiplier: Float? = 1.0
    @State var editedMultiplier: Float? = 1.0
    
    @State var selectedLuminanceImage = ""
    
    @State var selectingFilesToSave: Bool = false
    
    @State var multiplyDocument = FITSDocumentDocument(text: "Hello, world!")
    
    
    @State var imageArray :[String] = [
    "Empty"]
//    @State var redImageArray :[String] = [
//    "Empty"]
//    @State var blueImageArray :[String] = [
//    "Empty"]
//    @State var greenImageArray :[String] = [
//    "Empty"]
    
    @State var multipliedImage :CGImage?
    
    private var floatFormatter: NumberFormatter = {
              let f = NumberFormatter()
              f.numberStyle = .decimal
              f.maximumFractionDigits = 2
              return f
          }()
    
    
    var body: some View {
       
        
        VStack{
            Button(action: {
                
                PopulateImageField()
                multipliedImage = nil
                
                
            }, label: {
                Text("Populate Images")
            })
            //.disabled(document == nil)
            
            
            Spacer()
            
            HStack{
                
                Picker("Select Image", selection: $selectedLuminanceImage) {
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
                
                Text(verbatim: "Multiplication Constant:")
                .padding()
                TextField("The mulitplicationumber should be a positive floating point number.", value: $editedMultiplier, formatter: floatFormatter, onCommit: {
                    self.multiplier = self.editedMultiplier
                })
            
                    .padding()
                
                }
            
            Spacer()
            
        }
            
            
        
        VStack{
            
            //is setting the selected image files to be the names for each corresponding variable (I think?)
            Button(action: {multiplyTheImage(nameOfLuminanceDocument: selectedLuminanceImage,  multiplicationValue: multiplier!)}, label: {
                        Text("Multiply the Image")
                    })
            
            Button("Save"){
                
                saveFile()
                selectingFilesToSave = true
                
            }
            .fileExporter(isPresented: $selectingFilesToSave, document: multiplyDocument, contentType: .fitDocument, defaultFilename: "Muliply", onCompletion: { result in
                print("Picked: \(result)")
                
                //                let fileUrlsToAdd = try? result.get()
                //
                //                imageArray.append(contentsOf: fileUrlsToAdd!)
                //
                //                print(imageArray)
            })
        }
        
        VStack{
            //rawImage?.resizable().scaledToFit()
            if (multipliedImage != nil){
                Image((multipliedImage!), scale: 2.0, label: Text("Raw")).resizable().scaledToFit()
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
    
    func multiplyTheImage(nameOfLuminanceDocument: String, multiplicationValue: Float){
        
        print("the multiplication value is: ", multiplicationValue)
        
        if let index = listOfDocuments.documentName.firstIndex(of: nameOfLuminanceDocument) {
            
            // Get the Address of the Selected Document
               luminanceImage = listOfDocuments.documentList[index]
               
               luminanceWidth =  listOfDocuments.documentList[index].imageWidth.wrappedValue
               
               luminanceHeight = listOfDocuments.documentList[index].imageHeight.wrappedValue
            }
    
        //Get the floating point array of image values from the selected Document
        var luminanceFloat = luminanceImage!.wrappedValue.rawFloatData
        
        
        var luminanceMulitpliedImage :[Float] = Array(repeating: 0.0, count: Int(luminanceWidth!*luminanceHeight!))


        let multiplyValue :Float = self.multiplier!
        
        luminanceMulitpliedImage = vDSP.multiply(multiplyValue, luminanceFloat)
        
        print (luminanceFloat[10330], luminanceMulitpliedImage[10330])
        
        luminanceFloat = vDSP.clip(luminanceMulitpliedImage, to: 0.0...1.0)
        
        imageWidth = Int(luminanceWidth!)
        imageHeight = Int(luminanceHeight!)
        
        multiplyDocument.imageHeight = UInt(imageHeight)
        multiplyDocument.imageWidth = UInt(imageWidth)
        
        multiplyDocument.rawFloatData = []
        multiplyDocument.rawFloatData.append(contentsOf: luminanceFloat)
        
                    print("mulitplyDocument", multiplyDocument.rawFloatData[10133], multiplyDocument.imageWidth, multiplyDocument.imageHeight)
        
        let rowBytes :Int = Int(multiplyDocument.imageWidth) * MemoryLayout<Float>.size
        
        let starImage = returningCGImage(data: multiplyDocument.rawFloatData, width: Int(multiplyDocument.imageWidth), height: Int(multiplyDocument.imageHeight), rowBytes: rowBytes)
        
        
        multiplyDocument.starImage = starImage
        
        multiplyDocument.exportStarImage()
        
        multipliedImage = multiplyDocument.starImage
            
                        
            //colorImage = returningColorCGImage(data: rgbFloat, width: Int(luminanceWidth!), height: Int(luminanceHeight!), rowBytes: rowBytes)
            
        
        
        
        
    }
    
    func saveFile(){
        
        let floatData :[FITSByte_F] = multiplyDocument.rawFloatData.bigEndian
        
        multiplyDocument.myPrimaryHDU = PrimaryHDU(width: imageWidth, height: imageHeight, vectors: floatData)
        
        
        print(multiplyDocument.myPrimaryHDU)
    }
    
    

}


struct MultiplyByConstant_Previews: PreviewProvider {
    static var previews: some View {
        MultiplyByConstant()
    }
}
