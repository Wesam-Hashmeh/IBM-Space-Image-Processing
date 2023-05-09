//
//  FITSDocumentDocument.swift
//  Shared
//
//  Created by Jeff Terry on 8/13/21.
//

import SwiftUI
import UniformTypeIdentifiers
import FITS
import FITSKit
import Accelerate
import Accelerate.vImage
import simd
import CorePlot

/*extension UTType {
    static var exampleText: UTType {
        UTType(importedAs: "com.example.plain-text")
    }
}*/

extension UTType {
  static let fitDocument = UTType(
    exportedAs: "com.jtIIT.fit")
}

extension UTType {
  static let fitsDocument = UTType(
    exportedAs: "gov.nasa.gsfc.fits")
}



struct FITSDocumentDocument: FileDocument {
    
    var text: String
    var threeData: ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)?
    var ImageInfo: ([vImagePixelCount], CGImage, CGImage, CGImage, [Float], [Float], [Float])?
    var imageHeight: UInt = 0
    var imageWidth: UInt = 0
    var starImage :CGImage?
    var RawImage :CGImage?
    var MirrorImage :CGImage?
    var TransformImage :CGImage?
    var InverseTransformImage :CGImage?
    var autocorrelationImage :CGImage?
    var rawFloatData: [Float] = []
    var processedData: [Float] = []
    var myPrimaryHDU: PrimaryHDU?
    var primaryHDUString: String
    

    
    var autocorrelationValue = 1.0
    
    private let scratchURL: URL

    init(text: String = "Hello, world!") {
        self.text = text
        self.primaryHDUString = ""
        
        let tempURL = Self.makeTemporaryFileURL()
        self.scratchURL = tempURL
    }

    static var readableContentTypes: [UTType] { [.fitDocument, .fitsDocument] }

    init(configuration: ReadConfiguration) throws {
        print(configuration)
        print(configuration.file)
        
        let tempURL = Self.makeTemporaryFileURL()
        self.scratchURL = tempURL
        
        self.primaryHDUString = ""
        
        guard let data = configuration.file.regularFileContents
              
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        guard let read_data = try! FitsFile.read(data) else { throw CocoaError(.fileReadCorruptFile) }
        let prime = read_data.prime
        
//        print(prime)
        myPrimaryHDU = prime
        
        
            
        primaryHDUString += "\(String(describing: myPrimaryHDU))"
        
        
        
        self.text = configuration.file.filename!
        
        var newData: ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)?
        prime.v_complete(onError: {_ in
            print("CGImage creation error")
        }) { result in
            newData = result
        }
        
        self.threeData = newData!
        
        self.rawFloatData = threeData!.0
        
        print("the raw float data:", self.rawFloatData[10133])
        
        print(self.threeData!.1.height)
        self.imageWidth = self.threeData!.1.width
        self.imageHeight = self.threeData!.1.height
        
        print("Image Height =", self.imageHeight, "Image Width =", self.imageWidth)
        
        var maxData = newData!.0.max()
        var minData = newData!.0.min()
        let dataWidth = Int(newData!.1.width)
        let dataHeight = Int(newData!.1.height)
        let dataRowBytes = newData!.1.rowBytes
        
        if (maxData! > 1.0) {
            if (minData! < 1.0) {
                minData = 0.0
                maxData = 2048.0
                for i in 0 ..< newData!.0.count {
                    if (newData!.0[i] > maxData!) {
                        newData!.0[i] = maxData!
                    }
                    if (newData!.0[i] < minData!) {
                        newData!.0[i] = minData!
                    }
                }
            }
            
            //let normalizedData = normalizeData(data: newData!.0, max: maxData!, min: minData!)
            
            //newData!.0 = normalizedData
            
            newData!.1 = try! vImage_Buffer.init(
                cgImage: returningCGImage(
                    data: newData!.0,
                    width: dataWidth,
                    height: dataHeight,
                    rowBytes: dataRowBytes
                )
            )
        }
        
        ImageInfo = returnInfo(ThreeData: newData!)
        
        print(self.ImageInfo!.4.count)
        
//        self.imageWidth = 501
//        self.imageHeight = 501
//
//        var testArray :[Float] = Array(repeating: 0.0, count: Int(self.imageWidth*self.imageHeight))
//
//        testArray[250+254*Int(imageWidth)] = 1.0
//        testArray[250+254*Int(imageWidth)+1] = 1.0
//        testArray[250+254*Int(imageWidth)-1] = 1.0
//        testArray[250+254*Int(imageWidth)+2] = 1.0
//        testArray[250+254*Int(imageWidth)-2] = 1.0
//        testArray[250+254*Int(imageWidth)+3] = 1.0
//        testArray[250+254*Int(imageWidth)-3] = 1.0
//        testArray[250+254*Int(imageWidth)+4] = 1.0
//        testArray[250+254*Int(imageWidth)-4] = 1.0
//        testArray[250+253*Int(imageWidth)] = 1.0
//        testArray[250+253*Int(imageWidth)+1] = 1.0
//        testArray[250+253*Int(imageWidth)-1] = 1.0
//        testArray[250+253*Int(imageWidth)+2] = 1.0
//        testArray[250+253*Int(imageWidth)-2] = 1.0
//        testArray[250+253*Int(imageWidth)+3] = 1.0
//        testArray[250+253*Int(imageWidth)-3] = 1.0
//        testArray[250+253*Int(imageWidth)+4] = 1.0
//        testArray[250+253*Int(imageWidth)-4] = 1.0
//        testArray[250+252*Int(imageWidth)] = 1.0
//        testArray[250+252*Int(imageWidth)+1] = 1.0
//        testArray[250+252*Int(imageWidth)-1] = 1.0
//        testArray[250+252*Int(imageWidth)+2] = 1.0
//        testArray[250+252*Int(imageWidth)-2] = 1.0
//        testArray[250+252*Int(imageWidth)+3] = 1.0
//        testArray[250+252*Int(imageWidth)-3] = 1.0
//        testArray[250+252*Int(imageWidth)+4] = 1.0
//        testArray[250+252*Int(imageWidth)-4] = 1.0
//        testArray[250+251*Int(imageWidth)] = 1.0
//        testArray[250+251*Int(imageWidth)+1] = 1.0
//        testArray[250+251*Int(imageWidth)-1] = 1.0
//        testArray[250+251*Int(imageWidth)+2] = 1.0
//        testArray[250+251*Int(imageWidth)-2] = 1.0
//        testArray[250+251*Int(imageWidth)+3] = 1.0
//        testArray[250+251*Int(imageWidth)-3] = 1.0
//        testArray[250+251*Int(imageWidth)+4] = 1.0
//        testArray[250+251*Int(imageWidth)-4] = 1.0
//        testArray[250+250*Int(imageWidth)] = 1.0
//        testArray[250+250*Int(imageWidth)+1] = 1.0
//        testArray[250+250*Int(imageWidth)-1] = 1.0
//        testArray[250+250*Int(imageWidth)+2] = 1.0
//        testArray[250+250*Int(imageWidth)-2] = 1.0
//        testArray[250+250*Int(imageWidth)+3] = 1.0
//        testArray[250+250*Int(imageWidth)-3] = 1.0
//        testArray[250+250*Int(imageWidth)+4] = 1.0
//        testArray[250+250*Int(imageWidth)-4] = 1.0
//        testArray[250+249*Int(imageWidth)] = 1.0
//        testArray[250+249*Int(imageWidth)+1] = 1.0
//        testArray[250+249*Int(imageWidth)-1] = 1.0
//        testArray[250+249*Int(imageWidth)+2] = 1.0
//        testArray[250+249*Int(imageWidth)-2] = 1.0
//        testArray[250+249*Int(imageWidth)+3] = 1.0
//        testArray[250+249*Int(imageWidth)-3] = 1.0
//        testArray[250+249*Int(imageWidth)+4] = 1.0
//        testArray[250+249*Int(imageWidth)-4] = 1.0
//        testArray[250+248*Int(imageWidth)] = 1.0
//        testArray[250+248*Int(imageWidth)+1] = 1.0
//        testArray[250+248*Int(imageWidth)-1] = 1.0
//        testArray[250+248*Int(imageWidth)+2] = 1.0
//        testArray[250+248*Int(imageWidth)-2] = 1.0
//        testArray[250+248*Int(imageWidth)+3] = 1.0
//        testArray[250+248*Int(imageWidth)-3] = 1.0
//        testArray[250+248*Int(imageWidth)+4] = 1.0
//        testArray[250+248*Int(imageWidth)-4] = 1.0
//        testArray[250+247*Int(imageWidth)] = 1.0
//        testArray[250+247*Int(imageWidth)+1] = 1.0
//        testArray[250+247*Int(imageWidth)-1] = 1.0
//        testArray[250+247*Int(imageWidth)+2] = 1.0
//        testArray[250+247*Int(imageWidth)-2] = 1.0
//        testArray[250+247*Int(imageWidth)+3] = 1.0
//        testArray[250+247*Int(imageWidth)-3] = 1.0
//        testArray[250+247*Int(imageWidth)+4] = 1.0
//        testArray[250+247*Int(imageWidth)-4] = 1.0
//        testArray[250+246*Int(imageWidth)] = 1.0
//        testArray[250+246*Int(imageWidth)+1] = 1.0
//        testArray[250+246*Int(imageWidth)-1] = 1.0
//        testArray[250+246*Int(imageWidth)+2] = 1.0
//        testArray[250+246*Int(imageWidth)-2] = 1.0
//        testArray[250+246*Int(imageWidth)+3] = 1.0
//        testArray[250+246*Int(imageWidth)-3] = 1.0
//        testArray[250+246*Int(imageWidth)+4] = 1.0
//        testArray[250+246*Int(imageWidth)-4] = 1.0

        var powerOf2ArrayWidth = 2 * PowerOf2(testValue: Int(self.imageWidth)).twoToPowerOfm
        
        var powerOf2ArrayHeight = 2 * PowerOf2(testValue: Int(self.imageHeight)).twoToPowerOfm
    
        // Height must be extra factor of 2 for the inverse FFT to work
        powerOf2ArrayHeight *= 2
        
        print (powerOf2ArrayWidth, powerOf2ArrayHeight, self.imageWidth, self.imageHeight)

        var powerOf2Array :[Float] = Array(repeating: 0.0, count: Int(powerOf2ArrayWidth*powerOf2ArrayHeight))

        for width in stride(from: 0, to: Int(self.imageWidth), by: 1){

            for height in stride(from: 0, to: Int(self.imageHeight), by: 1){


//                powerOf2Array[width + height*powerOf2ArrayWidth] = testArray[width + height * Int(self.imageWidth)]
                
                powerOf2Array[width + height*powerOf2ArrayWidth] = self.ImageInfo!.5[width + height * Int(self.imageWidth)]


            }



        }
        /*
         //start block comment here to remove FFT and speed up image loading
        let rowBytes :Int = powerOf2ArrayWidth * MemoryLayout<Float>.size
                
        var mirrorRealFloats :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var imaginaryPixels :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var mirrorImaginaryPixels :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var returnRealPixels :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var returnMirrorRealPixels :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var returnImaginaryPixels :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var returnMirrorImaginaryPixels :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var returnImageAmplitude :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var returnAutocorrelation :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var returnInverseRealPixels :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var returnInverseImaginaryPixels :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var returnConjugateRealPixels :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var returnConjugateImaginaryPixels :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var inverseImageAmplitude :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        
        var multipliedFFTReal :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var multipliedFFTImaginary :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var inverseMultipliedFFTReal :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        var inverseMultipliedFFTImaginary :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight)
        
        
        let fftSetUp = vDSP.FFT2D(width: powerOf2ArrayWidth, height: powerOf2ArrayHeight, ofType: DSPSplitComplex.self)
        
        var rawArray :[Float] = []

        for item in stride(from: 0, to: powerOf2ArrayWidth*(powerOf2ArrayHeight/2), by: 1){
            rawArray.append(powerOf2Array[item]*1.0)
        }
            
        //Mirror the Array To Calculate The Autocorrelation
        //I(r)★I(r) = I(r)⭐️I*(-r) = Ft-1[Ft[I(r)]Ft[I(-r)]]
        //IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
        var mirrorRawArray :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight/2)
            
        for x in stride(from: 0, to: powerOf2ArrayWidth, by: 1){

            for y in stride(from: 0, to: powerOf2ArrayHeight/2, by: 1){


                mirrorRawArray[ x  + y*powerOf2ArrayWidth] = rawArray[(powerOf2ArrayWidth - 1 - x) + powerOf2ArrayWidth * y]

    //                normalTransformDisplay[(powerOf2ArrayWidth*4 + x) + (y+powerOf2ArrayWidth/4) * powerOf2ArrayWidth] = transformArray[x + powerOf2ArrayWidth * y]


                }

            }
                
        MirrorImage = returningCGImage(data: mirrorRawArray, width: powerOf2ArrayWidth, height: (powerOf2ArrayHeight/2), rowBytes: rowBytes)
            
        
        // This syntax gets rid of the Initialization of 'UnsafeMutablePointer<Float>' results in a dangling pointer Warning
                powerOf2Array.withUnsafeMutableBufferPointer {pointerToRealFloats in
                    imaginaryPixels.withUnsafeMutableBufferPointer { pointerToImaginaryFloats in
                        returnRealPixels.withUnsafeMutableBufferPointer { pointerToReturnRealPixels in returnImaginaryPixels.withUnsafeMutableBufferPointer { pointerToReturnImaginaryPixels in returnInverseRealPixels.withUnsafeMutableBufferPointer{
                                    pointerToreturnInverseRealPixels in
                                    returnInverseImaginaryPixels.withUnsafeMutableBufferPointer{
                                        pointerToreturnInverseImaginaryPixels in
                                            returnConjugateImaginaryPixels.withUnsafeMutableBufferPointer{
                                                pointerToReturnConjugateImaginaryPixels in returnConjugateRealPixels.withUnsafeMutableBufferPointer{
                                                            pointerToReturnConjugateRealPixels in returnMirrorImaginaryPixels.withUnsafeMutableBufferPointer{
                                                                    pointerToReturnMirrorImaginaryFloats in returnMirrorRealPixels.withUnsafeMutableBufferPointer{ pointerToReturnMirrorRealPixels in mirrorImaginaryPixels.withUnsafeMutableBufferPointer { pointerToMirrorImaginaryFloats in multipliedFFTReal.withUnsafeMutableBufferPointer{pointerToMultipliedFFTReal in multipliedFFTImaginary.withUnsafeMutableBufferPointer{pointerToMultipliedFFTImaginary in mirrorRealFloats.withUnsafeMutableBufferPointer{pointerToMirrorRealFloats in inverseMultipliedFFTReal.withUnsafeMutableBufferPointer{pointerToInverseMultipliedFFTReal in inverseMultipliedFFTImaginary.withUnsafeMutableBufferPointer{pointerToInverseMultipliedFFTImaginary in

                                        
                                
                        
                                
                                var sourceImageDSP = DSPSplitComplex(
                                    realp: pointerToRealFloats.baseAddress!,
                                    imagp: pointerToImaginaryFloats.baseAddress!)

                                var transformImageDSP = DSPSplitComplex(
                                    realp: pointerToReturnRealPixels.baseAddress!,
                                    imagp: pointerToReturnImaginaryPixels.baseAddress!)

                                var sourceMirrorImageDSP = DSPSplitComplex(
                                    realp: pointerToReturnMirrorRealPixels.baseAddress!,
                                    imagp: pointerToMirrorImaginaryFloats.baseAddress!)

                                var transformMirrorImageDSP = DSPSplitComplex(
                                    realp: pointerToReturnRealPixels.baseAddress!,
                                    imagp: pointerToReturnImaginaryPixels.baseAddress!)

                                //Create mirror of real of source image
                                for x in stride(from: 0, to: powerOf2ArrayWidth, by: 1){

                                    for y in stride(from: 0, to: powerOf2ArrayHeight/2, by: 1){


                                        pointerToReturnMirrorRealPixels[ x  + y*powerOf2ArrayWidth] = pointerToRealFloats[(powerOf2ArrayWidth - 1 - x) + powerOf2ArrayWidth * y]
                                    }

                                }

                                //Create mirror of imaginary of source image
                                for x in stride(from: 0, to: powerOf2ArrayWidth, by: 1){

                                    for y in stride(from: 0, to: powerOf2ArrayHeight/2, by: 1){


                                        pointerToReturnImaginaryPixels[ x  + y*powerOf2ArrayWidth] = pointerToImaginaryFloats[(powerOf2ArrayWidth - 1 - x) + powerOf2ArrayWidth * y]
                                    }

                                }

//                                fftSetUp?.transform(input: sourceImageDSP,
//                                                    output: &transformImageDSP,
//                                                    direction: .forward)

//                                vDSP.squareMagnitudes(transformImageDSP,
//                                                      result: &returnImageAmplitude)

                                var transformArray :[Float] = []

                                for item in stride(from: 0, to: powerOf2ArrayWidth*(powerOf2ArrayHeight), by: 1){
                                    transformArray.append(returnImageAmplitude[item]*1.0)

                                }

                                var inverseImageDSP = DSPSplitComplex(realp: pointerToreturnInverseRealPixels.baseAddress!, imagp: pointerToreturnInverseImaginaryPixels.baseAddress!)

//                                fftSetUp?.transform(input: transformImageDSP, output: &inverseImageDSP, direction: .inverse)
//
//                                vDSP.squareMagnitudes(inverseImageDSP,
//                                                      result: &inverseImageAmplitude)
//


                                /* Now try with vDSP_fft2d_zop */

                                let logX = Int(log2(Double(powerOf2ArrayWidth) + 0.1))
                                let logY = Int(log2(Double(powerOf2ArrayHeight/2) + 0.1))

                                let fftWeights :FFTSetup = vDSP_create_fftsetup(vDSP_Length(Int(maxOfAB(a: Double(logX), b: Double(logY)))), FFTRadix(kFFTRadix2))!

                                vDSP_fft2d_zop(fftWeights, &sourceImageDSP, 1, 0, &transformImageDSP, 1, 0, vDSP_Length(logX), vDSP_Length(logY), FFTDirection(FFT_FORWARD))

                                vDSP.squareMagnitudes(transformImageDSP, result: &returnImageAmplitude)

                                vDSP_fft2d_zop(fftWeights, &transformImageDSP, 1, 0, &inverseImageDSP, 1, 0, vDSP_Length(logX), vDSP_Length(logY), FFTDirection(FFT_INVERSE))

                                vDSP.squareMagnitudes(inverseImageDSP, result: &inverseImageAmplitude)


                                //for item in pointerToReturnImaginaryPixels{
                                  //  pointerToReturnImaginaryPixels[Int(item)] = //(-1)*pointerToReturnImaginaryPixels[Int(item)]
                                //}
                               // var conjOfTransformImageDSP = DSPSplitComplex(
                                 //   realp: pointerToReturnRealPixels.baseAddress!,
                                  //  imagp: //pointerToReturnImaginaryPixels.baseAddress!)
                               // }


                                //have to create pointers outside loop

                                //Conjugate of fft transform of image:
                                var conjOfTransformImageDSP = DSPSplitComplex(
                                    realp: pointerToReturnConjugateRealPixels.baseAddress!,
                                    imagp: pointerToReturnConjugateImaginaryPixels.baseAddress!)

                                vDSP_zvconj(&transformImageDSP, 1,
                                            &conjOfTransformImageDSP, 1, vDSP_Length(powerOf2ArrayWidth*powerOf2ArrayHeight/2))

                                //fft of mirror of original image
                                vDSP_fft2d_zop(fftWeights, &sourceMirrorImageDSP, 1, 0, &transformMirrorImageDSP, 1, 0, vDSP_Length(logX), vDSP_Length(logY), FFTDirection(FFT_FORWARD))


                                // CC of FFT of Original x FFT of Mirrored Image

                                 var multipliedFFT = DSPSplitComplex(
                                     realp: pointerToMultipliedFFTReal.baseAddress!,
                                     imagp: pointerToMultipliedFFTImaginary.baseAddress!)

                                //Real part multipliedFFT
                                 for x in stride(from: 0, to: powerOf2ArrayWidth, by: 1){

                                     for y in stride(from: 0, to: powerOf2ArrayHeight/2, by: 1){

                                        pointerToMultipliedFFTReal[x+y*powerOf2ArrayWidth] = (conjOfTransformImageDSP.realp[x+y*powerOf2ArrayWidth]*transformMirrorImageDSP.realp[x+y*powerOf2ArrayWidth]-conjOfTransformImageDSP.imagp[x+y*powerOf2ArrayWidth]*transformMirrorImageDSP.imagp[x+y*powerOf2ArrayWidth])

                                        // d = transformMirrorImageDSP.imagp
                                        // c = transformMirrorImageDSP.realp
                                        // b = conjOfTransformImageDSP.imagp
                                        // a = conjOfTransformImageDSP.realp

                                     }

                                 }
                                //Imaginary part multipliedFFT
                                 for x in stride(from: 0, to: powerOf2ArrayWidth, by: 1){

                                     for y in stride(from: 0, to: powerOf2ArrayHeight/2, by: 1){

                                        pointerToMultipliedFFTImaginary[x+y*powerOf2ArrayWidth] = (conjOfTransformImageDSP.realp[x+y*powerOf2ArrayWidth]*transformMirrorImageDSP.imagp[x+y*powerOf2ArrayWidth]+conjOfTransformImageDSP.imagp[x+y*powerOf2ArrayWidth]*transformMirrorImageDSP.realp[x+y*powerOf2ArrayWidth])

                                        // d = transformMirrorImageDSP.imagp
                                        // c = transformMirrorImageDSP.realp
                                        // b = conjOfTransformImageDSP.imagp
                                        // a = conjOfTransformImageDSP.realp

                                     }

                                 }

                                var inverseMultipliedFFT = DSPSplitComplex(
                                    realp: pointerToInverseMultipliedFFTReal.baseAddress!,
                                    imagp: pointerToInverseMultipliedFFTImaginary.baseAddress!)

                                // Get Inverse of FFT multiplication
                                                                        
                                                                        
                                //Mirror

//                                vDSP_fft2d_zop(fftWeights, &multipliedFFT, 1, 0, &inverseMultipliedFFT, 1, 0, vDSP_Length(logX), vDSP_Length(logY), FFTDirection(FFT_INVERSE))
                                                                        
                                //NoMirror
                                                                        
                                vDSP_fft2d_zop(fftWeights, &multipliedFFT, 1, 0, &multipliedFFT, 1, 0, vDSP_Length(logX), vDSP_Length(logY), FFTDirection(FFT_INVERSE))

                                vDSP.squareMagnitudes(transformImageDSP,result: &returnAutocorrelation)

                                                            }
                                                           }
                                                       }
                                                            }
                                                            }
                                                                   }

                                                                    }
                                                                
                                                            }
                                                
                                                }}
                                        
                                    }
                        }
                    }
                }
            }
        }

//        var rawArray :[Float] = []
        
        let autocorrelationMax = log10(returnAutocorrelation.max()!)
        let inverseAutocorrelationMax = 1.0/autocorrelationMax
        
        var autocorrelationInverseTransformArray :[Float] = []
        
        autocorrelationInverseTransformArray = vDSP.multiply(inverseAutocorrelationMax, returnAutocorrelation)
    

        autocorrelationImage = returningCGImage(data: autocorrelationInverseTransformArray, width: powerOf2ArrayWidth, height: (powerOf2ArrayHeight/2), rowBytes: rowBytes)


        
        print("rawArray Max", rawArray.max())
        RawImage = returningCGImage(data: rawArray, width: powerOf2ArrayWidth, height: (powerOf2ArrayHeight/2), rowBytes: rowBytes)

        
        var transformArray :[Float] = []

        for item in stride(from: 0, to: powerOf2ArrayWidth*(powerOf2ArrayHeight/2), by: 1){
            transformArray.append(returnImageAmplitude[item]*1.0)
            
        }
        
        
        for item in stride(from: 0, to: powerOf2ArrayWidth*(powerOf2ArrayHeight/2), by: 1){
            transformArray[item] = log10(transformArray[item])

        }

        var normalizingConstant = transformArray.max()!
        print("Transform Array max is ", transformArray.max()!)
        
        for item in stride(from: 0, to: powerOf2ArrayWidth*(powerOf2ArrayHeight/2), by: 1){
            transformArray[item] /= normalizingConstant

        }
        
        var normalTransformDisplay :[Float] = Array(repeating: 0.0, count: powerOf2ArrayWidth*powerOf2ArrayHeight/2)

        for x in stride(from: 0, to: powerOf2ArrayWidth/2, by: 1){

            for y in stride(from: 0, to: powerOf2ArrayHeight/4, by: 1){


                normalTransformDisplay[( x + powerOf2ArrayWidth/2 ) + (y + powerOf2ArrayHeight/4) * powerOf2ArrayWidth] = transformArray[x + powerOf2ArrayWidth * y]

//                normalTransformDisplay[(powerOf2ArrayWidth*4 + x) + (y+powerOf2ArrayWidth/4) * powerOf2ArrayWidth] = transformArray[x + powerOf2ArrayWidth * y]


            }

        }

        for x in stride(from: 0, to: powerOf2ArrayWidth/2, by: 1){

            for y in stride(from: powerOf2ArrayHeight/4, to: powerOf2ArrayHeight/2, by: 1){


                normalTransformDisplay[(x + powerOf2ArrayWidth/2) + (y - powerOf2ArrayHeight/4) * powerOf2ArrayWidth] = transformArray[x + powerOf2ArrayWidth * y]


            }

        }

        for x in stride(from: powerOf2ArrayWidth/2, to: powerOf2ArrayWidth, by: 1){

            for y in stride(from: powerOf2ArrayHeight/4, to: powerOf2ArrayHeight/2, by: 1){


                normalTransformDisplay[( x - powerOf2ArrayWidth/2 ) + (y - powerOf2ArrayHeight/4) * powerOf2ArrayWidth] = transformArray[x + powerOf2ArrayWidth * y]


            }

        }

        for x in stride(from: powerOf2ArrayWidth/2, to: powerOf2ArrayWidth, by: 1){

            for y in stride(from: 0, to: powerOf2ArrayHeight/4, by: 1){


                normalTransformDisplay[(x - powerOf2ArrayWidth/2) + (y + powerOf2ArrayHeight/4) * powerOf2ArrayWidth] = transformArray[x + powerOf2ArrayWidth * y]


            }

        }

        TransformImage = returningCGImage(data: normalTransformDisplay, width: powerOf2ArrayWidth, height: (powerOf2ArrayHeight/2), rowBytes: rowBytes)
        
//        TransformImage = returningCGImage(data: transformArray, width: powerOf2ArrayWidth, height: (powerOf2ArrayHeight/2), rowBytes: rowBytes)
        
        
        var inverseTransformArray :[Float] = []

        for item in stride(from: 0, to: powerOf2ArrayWidth*(powerOf2ArrayHeight/2), by: 1){
            inverseTransformArray.append(inverseImageAmplitude[item]*1.0)
            
//            print(realArray[item], item)
        }
        
        normalizingConstant = inverseTransformArray.max()!
        
        print("inverse transform normalizing constant is", normalizingConstant)
        
        for item in stride(from: 0, to: powerOf2ArrayWidth*(powerOf2ArrayHeight/2), by: 1){
            inverseTransformArray[item] /= (normalizingConstant)
        
        }

        InverseTransformImage = returningCGImage(data: inverseTransformArray, width: powerOf2ArrayWidth, height: (powerOf2ArrayHeight/2), rowBytes: rowBytes)
        
        // --------------------------------------------------
        //print(returnImageDSP.imagp[75])
        
        
        
        
        var autocorrelationTestingArray :[Float] = []
        let row = powerOf2ArrayHeight/4
        
        for x in stride(from: (powerOf2ArrayWidth/2 - 100), to: (powerOf2ArrayWidth/2 + 100), by: 1){
            
            autocorrelationTestingArray.append(autocorrelationInverseTransformArray[x+row*powerOf2ArrayWidth])
        }
        
        
        autocorrelationValue = Double(log10(autocorrelationTestingArray.max()!))
        
        
        print(autocorrelationValue)
        
        
        
        print("The Doc =", self.text)
 
        //end block comment here to remove FFT and speed up image loading
         */
    }
    
    func normalizeData(data: [FITSByte_F], max: Float, min: Float) -> [FITSByte_F] {
        return data.map { ($0 - min) / (max - min) }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {


        print("I am here.", configuration)
        //let data = try Data(contentsOf: self.scratchURL)
        
        //fileWrapper = wrapper
        
        var data = Data()
        
        let file = FitsFile(prime: myPrimaryHDU!)
        
        try file.write(to: &data)
        
        let wrapper = FileWrapper(regularFileWithContents: data)


       // return .init(regularFileWithContents: data)
        return (wrapper)
    }
    
    private static func makeTemporaryFileURL() -> URL {
        let name = UUID().uuidString
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(name)
            .appendingPathExtension("fits")
    }
    
    func beginExport() {
        let panel = NSSavePanel()
        panel.prompt = "Export"
        panel.allowedFileTypes = ["fits, fit, FIT, FITS"]
        
        guard panel.runModal() == .OK, let url = panel.url else { return }
        
        export(to: url)
    }
    
    func exportPNG(){
        
        let panel = NSSavePanel()
              panel.nameFieldLabel = "Export Image as:"
              panel.nameFieldStringValue = ""
              panel.canCreateDirectories = true
              panel.begin { response in
                  if response == NSApplication.ModalResponse.OK, let fileUrl = panel.url {
                      print(fileUrl)
                      
                      _ = writeCGImage(self.ImageInfo!.1, to: fileUrl)
                      
                  }
                  
            
        }
    
    }
    
    func exportStarImage(){
        
        let fileUrl = URL(string:"/Users/jterry94/Downloads/dark.tiff")
        
        let worked = writeCGImage(self.starImage!, to: fileUrl!)
    
        print(worked)
    }
    
    @discardableResult func writeCGImage(_ image: CGImage, to destinationURL: URL) -> Bool {
       // guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, kUTTypePNG, 1, nil) else { return false }
        guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, kUTTypePNG, 1, nil) else { return false }
        
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
    
    private func export(to url: URL) {
       
        print("MadeItToExport")

    }
    
}

