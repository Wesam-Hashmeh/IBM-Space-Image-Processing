//
//  Extensions.swift
//  FitsViewer
//
//  Created by anthony lim on 4/29/21.
//

import Foundation
import FITS
import FITSKit
import Accelerate
import Accelerate.vImage
import Combine
import CoreGraphics
import UniformTypeIdentifiers
import SwiftUI





func kArray(width: Int, height: Int, sigmaX: Float, sigmaY: Float, A: Float) -> [Float]
{
    let kernelwidth = width
    let kernelheight = height
    var kernelArray = [Float]()
    //var Volume = 2.0 * Float.pi * A * simgaX * sigmaY
    for i in 0 ..< kernelwidth{
        let xposition = Float(i - kernelwidth / 2)
        for j in 0 ..< kernelheight{
            let yposition = Float(j - kernelheight / 2)
            let xponent = -xposition * xposition / (Float(2.0) * sigmaX * sigmaX)
            let yponent = -yposition * yposition / (Float(2.0) * sigmaY * sigmaY)
            let answer = A * exp (xponent + yponent)
            kernelArray.append(answer)
        }
    }
    let sum = kernelArray.reduce(0, +)
    for i in 0 ..< kernelArray.count{
        kernelArray[i] = kernelArray[i] / sum
    }
    return kernelArray
}

func bendValue(blurredHistogramBin: [vImagePixelCount], histogramcount: Int) -> (Float, Float) {
    let (bendValue, _, _) = getHistogramLowerMaxUpperPixel(histogramBin: blurredHistogramBin, histogramcount: histogramcount)
    return (bendValue, bendValue)
}

func ddpProcessed(OriginalPixelData: [Float], BlurredPixeldata: [Float], Bendvalue : Float, AveragePixel: Float, MinPixel : Pixel_F) -> [Float]{
    var ddpPixeldata = [Float]()
    for i in 0 ..< OriginalPixelData.count{
        let answer = AveragePixel * (OriginalPixelData[i]/(BlurredPixeldata[i] + Bendvalue)) + MinPixel
        ddpPixeldata.append(answer)
    }
    return ddpPixeldata
}
func ddpScaled(ddpPixelData: [Float], imageWidth: Int, imageHeight: Int) -> [Float]{
    var ddpScaled = [Float]()
    let ddpMax = Float(ddpPixelData.max()!)
    let ddpMin = Float(ddpPixelData.min()!)
    let adjustable = ddpMax - ddpMin
    for i in 0 ..< ddpPixelData.count{
        let answer = (ddpPixelData[i] - ddpMin) / adjustable
        ddpScaled.append(answer)
    }
    
    let dataRowBytes = imageWidth * 4
    
    var summedBuffer = try! vImage_Buffer.init(
        cgImage: returningCGImage(
            data: ddpScaled,
            width: Int(imageWidth),
            height: Int(imageHeight),
            rowBytes: Int(dataRowBytes)
        )
    )
    
    let histogramcount = 1024
   // let histogramBin = histogram(dataMaxPixel: Pixel_F(data.max()!), dataMinPixel: Pixel_F(data.min()!), buffer: buffer, histogramcount: UInt32(histogramcount))
    let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: summedBuffer, histogramcount: UInt32(histogramcount))
    
    let histogramValues = getHistogramLowerMaxUpperPixel(histogramBin: histogramBin, histogramcount: histogramcount)
    
    let histogramMin = histogramValues.0
    
    ddpScaled = vDSP.clip(ddpScaled, to: histogramMin...1.0)
    
    let max = ddpScaled.max()!
    ddpScaled = vDSP.add(Float(-histogramMin), ddpScaled)
    
    if ( max >= (1.0 - max.ulp)){
        
        ddpScaled = vDSP.multiply((1.0/(ddpScaled.max()!-ddpScaled.min()!)), ddpScaled)
    }
    
    print("ddpmin = ", histogramMin, ddpScaled.max()!, ddpScaled.min()!)
    
    return ddpScaled
}

func histogram(dataMaxPixel: Pixel_F, dataMinPixel: Pixel_F, buffer : vImage_Buffer, histogramcount: UInt32) -> [vImagePixelCount]{
    var mutatingBuffer = buffer
    var histogramBin = [vImagePixelCount](repeating: 0, count: Int(histogramcount))
    histogramBin.withUnsafeMutableBufferPointer()
    { Ptr in
        let error =
        vImageHistogramCalculation_PlanarF(&mutatingBuffer, Ptr.baseAddress!, UInt32(histogramcount), dataMinPixel, dataMaxPixel, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else {
            fatalError("Error calculating histogram: \(error)")
        }
    }
    print(histogramBin)
    return histogramBin
}

func returningCGImage(data: [Float], width: Int, height: Int, rowBytes: Int) -> CGImage{
    let pixelDataAsData = Data(fromArray: data)
    let cfdata = NSData(data: pixelDataAsData) as CFData
    
    let provider = CGDataProvider(data: cfdata)!
    
    let bitmapInfo: CGBitmapInfo = [
        .byteOrder32Little,
        .floatComponents]
    
    let pixelCGImage = CGImage(width:  width, height: height, bitsPerComponent: 32, bitsPerPixel: 32, bytesPerRow: rowBytes, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    return pixelCGImage
}

func returningColorCGImage(data: [Float], width: Int, height: Int, rowBytes: Int) -> CGImage{
    let pixelDataAsData = Data(fromArray: data)
    let cfdata = NSData(data: pixelDataAsData) as CFData
    
    let provider = CGDataProvider(data: cfdata)!
    
    let bitmapInfo: CGBitmapInfo = [
        .byteOrder32Little,
        .floatComponents]
    
    let pixelCGImage = CGImage(width:  width, height: height, bitsPerComponent: 32, bitsPerPixel: 96, bytesPerRow: rowBytes, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    return pixelCGImage
}

func OptValue(histogram_in : [vImagePixelCount], histogramcount : Int) -> (Pixel_F, Pixel_F, Int){
    var MaxPixel = 0
    var MinPixel = 0
    let PixelLimitingCount = Int(Double(histogram_in.reduce(0,+)) * 0.005)
    var minimumCutoff = 1
    for i in 0 ..< histogramcount {
        if histogram_in[i] > PixelLimitingCount{
            MinPixel = i
            break
        }
    }
    if MinPixel > 20 {
        MinPixel = MinPixel - 10
    }
    if MinPixel < 5 {
        MinPixel = 1
        minimumCutoff = 0
    }
    
    for i in 0 ..< histogramcount{
        if histogram_in[i] > 10{
            MaxPixel = i
        }
        
    }
    let difference = MaxPixel - MinPixel
    if difference < 30 {
        MaxPixel = MinPixel + Int(Double(histogramcount) * 0.1)
    }
    let MaxPixel_F = Pixel_F(Float(MaxPixel) / Float(histogramcount))
    let MinPixel_F = Pixel_F(Float(MinPixel) / Float(histogramcount))
    return (MaxPixel_F, MinPixel_F, minimumCutoff)
}

func forceMinPixelData(PixelData : [Float], MinimumLimit: Float) -> [Float]{
    var PixelData = PixelData
    for i in 0 ..< PixelData.count{
        if PixelData[i] < MinimumLimit{
            PixelData[i] = MinimumLimit
        }
    }
    return PixelData
}

func getHistogramLowerMaxUpperPixel(histogramBin: [vImagePixelCount], histogramcount: Int) -> (Float, Float, Float) {
    let histogramMax = histogramBin.max()
    let peakIndex = histogramBin.firstIndex(of: histogramMax!)
    
    // Calculating lower min index
    var lowerMinIndex = peakIndex!
    while (lowerMinIndex >= 1 && histogramBin[lowerMinIndex] >=  UInt(Float(histogramMax!) / 10.0) ) {
        lowerMinIndex -= 1
}

// Calculating upper min index
var upperMinIndex = peakIndex!
while (upperMinIndex < histogramcount && histogramBin[upperMinIndex] >= UInt(Float(histogramMax!) / 10.0) ) {
        upperMinIndex += 1
    }
    
    let histogramLowerMinPixel = (Float(lowerMinIndex) * 1.0) / Float(histogramcount)
    let histogramUpperMinPixel = (Float(upperMinIndex) * 1.0) / Float(histogramcount)
    let histogramMaxPixel = (Float(peakIndex!) * 1.0) / Float(histogramcount)
    
    print("histPixel = ", lowerMinIndex, peakIndex!, upperMinIndex)
    print("hist = ", histogramLowerMinPixel, histogramMaxPixel, histogramUpperMinPixel)
    return (histogramLowerMinPixel, histogramMaxPixel, histogramUpperMinPixel)
}

func returnInfo(ThreeData : ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)) -> ([vImagePixelCount], CGImage, CGImage, CGImage, [Float], [Float], [Float]){
    let threedata = ThreeData
    //target data
    let data = threedata.0
    //Buffer from FITS File
    let buffer = threedata.1
    //Grayscale format from FITS file
    let format = threedata.2
    //destination buffer
    let width :Int = Int(buffer.width)
    let height: Int = Int(buffer.height)
    let rowBytes :Int = width*4
    let histogramcount = 2048
    let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: buffer, histogramcount: UInt32(histogramcount))
    //Return three data, Histogram(0), Maximum Pixel Value(1), Minimum Pixel Value(2), Cutoff?(3) = 0 no, 1 yes
    let OptimizedHistogramContents = OptValue(histogram_in: histogramBin, histogramcount: histogramcount)
    let lowerPixelLimit = OptimizedHistogramContents.1
    
    var OriginalPixelData = (buffer.data.toArray(to: Float.self, capacity: Int(buffer.width*buffer.height)))
    let originalImage = (try? buffer.createCGImage(format: format))!
    
    OriginalPixelData = forceMinPixelData(PixelData: OriginalPixelData, MinimumLimit: lowerPixelLimit)
    let forcedMinOriginalImage = returningCGImage(data: OriginalPixelData, width: width, height: height, rowBytes: rowBytes)
    
    let forcedOriginalData = returningCGImage(data: OriginalPixelData, width: width, height: height, rowBytes: rowBytes)
    var forcedbuffer = try! vImage_Buffer(cgImage: forcedOriginalData, format: format)
    
    var blurredbuffer = try! vImage_Buffer(cgImage: forcedMinOriginalImage, format: format)
    
    let kernelwidth = 9
    let kernelheight = 9
    let sigmaX: Float = 0.75
    let sigmaY: Float = 0.75
    let A : Float = 1.0
    
    var kernelArray = kArray(width: kernelwidth, height: kernelheight, sigmaX: sigmaX, sigmaY: sigmaY, A: A)
    vImageConvolve_PlanarF(&forcedbuffer, &blurredbuffer, nil, 0, 0, &kernelArray, UInt32(kernelwidth), UInt32(kernelheight), 0, vImage_Flags(kvImageEdgeExtend))

    let BlurredPixelData = (blurredbuffer.data.toArray(to: Float.self, capacity: width * height))
    
    OriginalPixelData = (buffer.data.toArray(to: Float.self, capacity: width * height))
    
    //Bendvalue of DDP
    let blurredHistogramBin = histogram(dataMaxPixel: BlurredPixelData.max()!, dataMinPixel: BlurredPixelData.min()!, buffer: blurredbuffer, histogramcount: UInt32(histogramcount))
    let (bendValue, minValue) = bendValue(blurredHistogramBin: blurredHistogramBin, histogramcount: histogramcount)
//    let bendvalue = bendValue(AdjustedData: BlurredPixelData, lowerPixelLimit: lowerPixelLimit) //return bendvalue as .0, and averagepixeldata as .1

    let ddpPixelData = ddpProcessed(OriginalPixelData: OriginalPixelData, BlurredPixeldata: OriginalPixelData, Bendvalue: bendValue, AveragePixel: BlurredPixelData.mean, MinPixel: minValue)
    var DDPScaled = ddpScaled(ddpPixelData: ddpPixelData, imageWidth: width, imageHeight: height)
    let ConvolveImage = returningCGImage(data: BlurredPixelData, width: width, height: height, rowBytes: rowBytes)
    
    
    let DDPwithScale = returningCGImage(data: DDPScaled, width: width, height: height, rowBytes: rowBytes)
    
    // Deallocate buffers
    forcedbuffer.free()
    blurredbuffer.free()
    
    print("called")
    return(histogramBin, originalImage,  DDPwithScale, ConvolveImage, OriginalPixelData, DDPScaled, data)
    }

func returnRawFloat(RawData : ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)) -> ([Float]){
    
    //Buffer from FITS File
    let buffer = RawData.1
    
    //destination buffer
    let width :Int = Int(buffer.width)
    let height: Int = Int(buffer.height)
    let OriginalPixelData = (buffer.data.toArray(to: Float.self, capacity: Int(width*height)))
    print("called")
    return(OriginalPixelData)
}

func exportPNG(withImage: CGImage){
    let panel = NSSavePanel()
    panel.nameFieldLabel = "Export Image as:"
    panel.nameFieldStringValue = ""
    panel.canCreateDirectories = true
    panel.begin { response in
        if response == NSApplication.ModalResponse.OK, let fileUrl = panel.url {
            print(fileUrl)
            
            _ = writeCGImage(withImage, to: fileUrl)
            
        }
        
        
    }
    
}

@discardableResult func writeCGImage(_ image: CGImage, to destinationURL: URL) -> Bool {
    // guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, kUTTypePNG, 1, nil) else { return false }
    guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, kUTTypePNG, 1, nil) else { return false }
    
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}

/// PowerOf2
/// Calculates the closed but lower power of two fo a number
/// - Parameter testValue: number to get the closest put lower power of two
/// - Returns: Original Number, Power of 2 exponent, Value of the Closest but Lower Power of Two
func PowerOf2(testValue: Int) -> (n: Int, m: Int, twoToPowerOfm: Int){
    
    let n = testValue
    var m = 0
    var twoToPowerOfm = 1
    
    if (n <= 1){
        
        return (n: n, m: m, twoToPowerOfm: twoToPowerOfm)
        
    }
    
    m = 1
    twoToPowerOfm = 2
    
    repeat {
        
        m += 1
        twoToPowerOfm *= 2
        
    } while (2*(twoToPowerOfm) <= n)
    
    
    return (n: n, m: m, twoToPowerOfm: twoToPowerOfm)
    
}

func maxOfAB(a: Double, b: Double) -> Double{
    
    if(a > b) {
        
        return (a)
    }
    
    return (b)
    
    
}

func sortTheArray<T: Comparable>(array: [T])->[T]{
    
    return (array.sorted{$0 < $1 })
    
}

func calculateMedian(array: [Float])->Float{
    
    
    let counter = array.count
    let item = counter/2
    var median :Float = 0.0
    let divisor :Float = 1.0/2.0
    
    if counter%2 == 0 {
        
        
        
        median = (array[item] + array[item - 1])*divisor
    }
    else{
        
        median = (array[item] )
        
    }
    
    return median
}

//func histogram() {
//    
//    
//    let histogramCount :UInt32 = 60000
//    var histogramZeroLevel = 0.0
//    var histogramAboveBackground = 5.0
//    var histogramCutoff = 0.0
//    var imageMinimum :Float = 100000.0
//    
//    let sourceRowBytes = threedata.1.rowBytes
//    
//    OriginalPixelData.withUnsafeMutableBufferPointer {pointerToOriginalFloats in
//        
//        
//        var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToOriginalFloats.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: sourceRowBytes)
//        
//        let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: rawvImageBuffer, histogramcount: histogramCount)
//        
//        
//        
//        //calculate the 0 level of the histogram
//        for i in stride(from: 3, to: 22, by: 1){
//            
//            histogramZeroLevel += Double(histogramBin[i])
//            
//        }
//        
//        histogramZeroLevel /= Double(20.0)
//        
//        
//        
//        histogramCutoff = histogramZeroLevel*histogramAboveBackground
//        
//        var histogramCounter = 3
//        
//        while(histogramBin[histogramCounter] < UInt(cutoff)){
//            
//            histogramCounter += 1
//            
//        }
//        
//        imageMinimum = (Float(histogramCounter) * 1.0/Float(histogramcount))
//        
//        
//    }
//    
//    OriginalPixelData = vDSP.add(-imageMinimum, OriginalPixelData)
//    
//}

class DocumentList: ObservableObject {
    @Published var documentName: [String] = []
    @Published var documentList: [DocumentBinding] = []
}

extension UnsafeMutableRawPointer {
    func toArray<T>(to type: T.Type, capacity count: Int) -> [T]{
        let pointer = bindMemory(to: type, capacity: count)
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }
}
