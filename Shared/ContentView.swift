//
//  ContentView.swift
//  Shared
//
//  Created by Jeff Terry on 8/13/21.
//
/*
 import SwiftUI
 
 struct ContentView: View {
 @Binding var document: FITSDocumentDocument
 
 var body: some View {
 TextEditor(text: $document.text)
 }
 }
 
 struct ContentView_Previews: PreviewProvider {
 static var previews: some View {
 ContentView(document: .constant(FITSDocumentDocument()))
 }
 }
 */

//
//  ContentView.swift
//  Shared
//
//  Created by anthony lim on 4/20/21.
//

import SwiftUI
import FITS
import FITSKit
import Accelerate
import Accelerate.vImage
import Combine
import UniformTypeIdentifiers
import CorePlot

typealias plotDataType = [CPTScatterPlotField : Double]

struct ContentView: View {
    
    @Binding var document: FITSDocumentDocument
    @ObservedObject var plotDataModel = PlotDataClass(fromLine: true)
    @ObservedObject private var dataCalculator = CalculatePlotData()
    
    @State var Val: Bool = false
    @State var ImageString = "Process Image"
    @State var threeData: ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)?
    @State var scale: CGFloat = 1.0
    @State var brightScale: CGFloat = 1.0
    
    @State var selectingFilesToSave: Bool = false
    @State var ddpDocument = FITSDocumentDocument(text: "Hello, world!")
    
    func saveFile(){
        ddpDocument.imageWidth = document.imageWidth
        ddpDocument.imageHeight = document.imageHeight
        ddpDocument.rawFloatData.append(contentsOf: document.ImageInfo!.5)
        let floatData :[FITSByte_F] = ddpDocument.rawFloatData.bigEndian
        ddpDocument.myPrimaryHDU = PrimaryHDU(width: Int(ddpDocument.imageWidth), height: Int(ddpDocument.imageHeight), vectors: floatData)
        print(ddpDocument.myPrimaryHDU!)
    }
    
    var body: some View {
        HStack{
            TabView{
                VStack{
                    HStack{
                        //rawImage?.resizable().scaledToFit()
                        if (document.ImageInfo?.1 != nil){
                            Image(document.ImageInfo!.1, scale: 1.0, label: Text("Raw Image")).resizable().scaledToFit()
                        }
                    }
                    Divider()
                    
                    VStack{
                        
                        HStack{
                            
                            CorePlot(dataForPlot: $plotDataModel.plotData, changingPlotParameters: $plotDataModel.changingPlotParameters)
                                .setPlotPadding(left: 10)
                                .setPlotPadding(right: 10)
                                .setPlotPadding(top: 10)
                                .setPlotPadding(bottom: 10)
                                .padding()
                            
                            
                            Button(action: {
                                displayHistogram()
                            }) {
                                Text("Histogram")
                            }
                            
                        }
                        
                        
                        
                        
                        
                    }.frame(minHeight: 200, maxHeight: 300)
                }
                HStack{
                    //processedImage?.resizable().scaledToFit()
                    //     $document.processedImage
                    
                    if (document.ImageInfo?.2 != nil){
                        
                        //ScrollView([.vertical,.horizontal], showsIndicators: true){
                        
                        Image((document.ImageInfo!.2), scale: brightScale, label: Text("Processed Image")).resizable()
                            .scaleEffect(brightScale)
                            .aspectRatio(contentMode: .fit)
                            .gesture(MagnificationGesture()
                                .onChanged { value in
                                    self.brightScale = value.magnitude
                                }
                            )
                        
                        Button("Save"){
                            saveFile()
                            selectingFilesToSave = true
                        }
                        .fileExporter(isPresented: $selectingFilesToSave, document: ddpDocument, contentType: .fitDocument, defaultFilename: "DDP_\(document.text)", onCompletion: { result in
                            print("Picked: \(result)")
                        })

                    }
                    
                    //}
                    
                    
                }
                HStack{
                    //processedImage?.resizable().scaledToFit()
                    //     $document.processedImage
                    
                    if (document.starImage != nil){
                        Image((document.starImage!), scale: 2.0, label: Text("Raw")).resizable().scaledToFit()
                        
                        Button("Save"){
                            saveFile()
                            selectingFilesToSave = true
                        }
                    }
                }
                HStack{
                    //processedImage?.resizable().scaledToFit()
                    //     $document.processedImage
                    
                    if (document.RawImage != nil){
                        Image((document.RawImage!), scale: 2.0, label: Text("Raw")).resizable().scaledToFit()
                    }
                }
                HStack{
                    //processedImage?.resizable().scaledToFit()
                    //     $document.processedImage
                    
                    if (document.TransformImage != nil){
                        Image((document.TransformImage!), scale: 2.0, label: Text("Raw")).resizable().scaledToFit()
                    }
                }
                HStack{
                    //processedImage?.resizable().scaledToFit()
                    //     $document.processedImage
                    
                    if (document.InverseTransformImage != nil){
                        Image((document.InverseTransformImage!), scale: 2.0, label: Text("Raw")).resizable().scaledToFit()
                        
                    }
                }
                HStack{
                    //processedImage?.resizable().scaledToFit()
                    //     $document.processedImage
                    
                    if (document.autocorrelationImage != nil){
                        Image((document.autocorrelationImage!), scale: scale, label: Text("Raw")).resizable()
                            .scaleEffect(scale)
                            .aspectRatio(contentMode: .fit)
                            .gesture(MagnificationGesture()
                                .onChanged { value in
                                    self.scale = value.magnitude
                                }
                            )
                    }
                }
                
                HStack{
                    //processedImage?.resizable().scaledToFit()
                    //     $document.processedImage
                    
                    if (document.myPrimaryHDU != nil){
                        VStack{
                            Text("FITS Header:")
                            TextEditor(text: $document.primaryHDUString)
                        }
                    }
                }
            }
            
            VStack{
                Button(action: {
                    displayHistogram()
                }) {
                    // How the button looks like
                }
                
                Spacer()
                
                Text(String($document.autocorrelationValue.wrappedValue))
                
                
            }
            
        }
    }
    
    func displayHistogram() {
        dataCalculator.plotDataModel = plotDataModel
        dataCalculator.plotDataModel?.zeroData()
        dataCalculator.plotHistogram(histogram: document.ImageInfo!.0)
        
        
        let file = "histogram.txt" //this is the file. we will write to and read from it
        var text = "" //just a text
        
        for item in document.ImageInfo!.0 {
            text += String(format: "%d\n", item)
        }
            
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {

            let fileURL = dir.appendingPathComponent(file)

            //writing
            do {
                try text.write(to: fileURL, atomically: false, encoding: .utf8)
            }
            catch {/* error handling here */}

        }
        
    }
    
    func buttonTap(){
        
        let bummer = document.imageHeight
        document.imageHeight = 22
        
        print("Jeff", document.text)
        print(document.imageHeight)
        
        document.imageHeight = bummer
        print(document.imageHeight)
        
        let floatData :[FITSByte_F] = document.ImageInfo!.4
        let width = document.imageWidth
        let height = document.imageHeight
        
        let myPrimaryHDU = PrimaryHDU(width: Int(width), height: Int(height), vectors: floatData)
        
        
        print(myPrimaryHDU)
        
        
        //        var myAnyHDU = AnyHDU()
        //        //var myDataUnit = DataUnit()
        //
        //      //  myDataUnit.count = threeData.1.width * threeData.1.height
        //
        //        myAnyHDU.bzero = 0
        //        myAnyHDU.naxis = 2
        //        myAnyHDU.bscale = 1
        ////        myAnyHDU.naxis1 = threeData.1.width
        //        myAnyHDU.naxis2 = threeData.1.height
        // myAnyHDU.dataUnit =
        
    }
    
}

extension Data {
    
    init<T>(fromArray values: [T]) {
        self = values.withUnsafeBytes { Data($0) }
    }
    
    func toArray<T>(type: T.Type) -> [T] where T: ExpressibleByIntegerLiteral {
        var array = Array<T>(repeating: 0, count: self.count/MemoryLayout<T>.stride)
        _ = array.withUnsafeMutableBytes { copyBytes(to: $0) }
        return array
    }
}



