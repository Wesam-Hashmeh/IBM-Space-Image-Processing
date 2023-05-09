//
//  Mathematics.swift
//  Mathematics
//
//  Created by Jeff_Terry on 11/15/21.
//
// Mathematics: Responsible for rotation and translation of images, as well as
// Adding/combining similar images together, adding pixel values within
// 1.5 standard deviations of the mean values for that site.

import SwiftUI
import Accelerate
import Accelerate.vImage

struct Mathematics: View {
    
    @EnvironmentObject var listOfDocuments: DocumentList
    
    @FocusedBinding(\.document) var document
    
    @State var dataFloat :DocumentBinding? = nil
    @State var dataWidth :UInt? = nil
    @State var dataHeight :UInt? = nil
    
    @State var mathImage :CGImage?
    
    
    
    @State var selectedImage = ""
    
    @State var imageArray :[String] = [
        "Empty"]
    
    var body: some View {

        VStack{
            Button(action: {PopulateImageField()}, label: {
                Text("Populate Images")
            })
            //.disabled(document == nil)
            Spacer()
            
            Button(action: {applyAffineTransformationToRotateandTranslate(nameOfSelectedDocument: selectedImage)}, label: {
                Text("Rotate and Translate Image")
            })
            
            Spacer()
            
            
            Picker("Select an Image", selection: $selectedImage) {
                ForEach($imageArray.wrappedValue, id: \.self) {
                    Text($0)
                }
            }
            /*.onReceive([self.selectedImage].publisher.first()) { value in
             self.doSomethingWith(value: value)
             }*/
            
        }
        
        VStack{
            //rawImage?.resizable().scaledToFit()
            if (mathImage != nil){
                Image((mathImage!), scale: 2.0, label: Text("Raw")).resizable().scaledToFit()
            }
        }

        
    }
    
    /// what this does
    func PopulateImageField(){
        
        imageArray.removeAll()
        
        imageArray.append(contentsOf: listOfDocuments.documentName)
        
        let transformDocument = listOfDocuments.documentList[0]
        
        print(transformDocument.imageHeight)
        
        let imageHeight = transformDocument.imageHeight.wrappedValue
        
        print(imageHeight)
        
        print("Transforming")
        print(document)
        
    }
    
    
    /// rotates and translates images
    /// - Parameters:
    ///   - imageData: Data from selected image
    ///   - transformedOutput: Output from the rotate/translate function
    ///   - sourceRowBytes: Utilized in the transformed output variable
    func rotateAndTranslateImage(_ imageData: inout [Float], _ transformedOutput: inout [Float], _ sourceRowBytes: Int) {
        imageData.withUnsafeMutableBufferPointer {pointerToImageFloats in
            transformedOutput.withUnsafeMutableBufferPointer {pointToTransformedData in
                
                
                
                var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToImageFloats.baseAddress, height: vImagePixelCount(Int(dataHeight!)), width: vImagePixelCount(Int(dataWidth!)), rowBytes: sourceRowBytes)
                
                var finalvImageBuffer = vImage_Buffer(data: pointToTransformedData.baseAddress, height: vImagePixelCount(Int(dataHeight!)), width: vImagePixelCount(Int(dataWidth!)), rowBytes: sourceRowBytes)
                
                let radians = CGFloat(-10.0 * Float.pi/180.0)
                
                let cgTransform = CGAffineTransform.identity
                //.translatedBy(x: 124,
                //              y: -1222)
                //.translatedBy(x: CGFloat(Int(dataWidth!)-1764), y: -571)
                    //.translatedBy(x: 1200, y: -700)
                    .rotated(by: radians)
                
                
                
                var transformationMatrix :vImage_AffineTransform = vImage_AffineTransform(a: Float(cgTransform.a), b: Float(cgTransform.b), c: Float(cgTransform.c), d: Float(cgTransform.d), tx: Float(cgTransform.tx), ty: Float(cgTransform.ty))
                
                let backgroundColor :Pixel_F = 0.0
                
                let err = vImageAffineWarp_PlanarF(&rawvImageBuffer, &finalvImageBuffer, nil, &transformationMatrix, backgroundColor, vImage_Flags(kvImageBackgroundColorFill))
                
                
            }
        }
        
        mathImage = returningCGImage(data: transformedOutput, width: Int(dataWidth!), height: Int(dataHeight!), rowBytes: sourceRowBytes)
    }
    
    /// applies the Affine translation (a type of euclidean transformation that preserves parallels and lines) to the selected image.
    /// - Parameter nameOfSelectedDocument: As written on the tin, this variable is just the name of the selected document chosen to be translated.
    func applyAffineTransformationToRotateandTranslate(nameOfSelectedDocument: String) {
        print(nameOfSelectedDocument)
       
       if let index = listOfDocuments.documentName.firstIndex(of: nameOfSelectedDocument) {
           
           // Get the Address of the Selected Document
              dataFloat = listOfDocuments.documentList[index]
              
              dataWidth =  listOfDocuments.documentList[index].imageWidth.wrappedValue
              
              dataHeight = listOfDocuments.documentList[index].imageHeight.wrappedValue
           }
       
//        print(dataFloat!.wrappedValue.ImageInfo!.4[3])
//        print(dataFloat!.wrappedValue.ImageInfo!.4[6])
//        print(dataFloat!.wrappedValue.ImageInfo!.4[780])
       
       //Get the floating point array of image values from the selected Document
       var imageData = dataFloat!.wrappedValue.ImageInfo!.4
       
       let sourceRowBytes :Int = Int(dataWidth!) * MemoryLayout<Float>.size
       
       var transformedOutput :[Float] = Array(repeating: Float(0.0), count: Int(dataWidth!*dataHeight!))
       
        rotateAndTranslateImage(&imageData, &transformedOutput, sourceRowBytes)
       
        var alignedDocument = FITSDocumentDocument(text: "Hello, world!")
        //aligned document variable most likely a diagnostic tool, not touching it. -DB
        
       
    }
}

struct Mathematics_Previews: PreviewProvider {
    static var previews: some View {
        Mathematics()
    }
}
