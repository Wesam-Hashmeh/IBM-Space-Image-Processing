//
//  SummingSubsections.swift
//  FITSDocument
//
//  Created by Megan Burrill on 4/14/22.
//

import Foundation

import SwiftUI
import UniformTypeIdentifiers
import FITS
import FITSKit
import Accelerate


class SummingSubsections: NSObject, ObservableObject{
    
    //var imageHeight = 2080
    //var imageWidth = 3072
    
    var imageHeight = 0
    var imageWidth = 0
    
    var numberOfStandardDeviationsAway = 1.5
    var dataFromAllTheImagesToCombine : [[Float]] = []
    func sumSubsectionOfImages()-> [Float]{

            var deviation :[Float] = []
            var mean :[Float] = []
            var pointArray :[Float] = []
            var contributionOfEachPixel :[Int] = Array(repeating: 1, count: imageHeight*imageWidth)
            var summedFloatArray :[Float] = Array(repeating: 0.0, count: imageHeight*imageWidth)


            if dataFromAllTheImagesToCombine.count == 0 {


                return (summedFloatArray)


            }


            // Calculate Standard Deviation and Mean
            for pixel in stride(from: 0, to: imageHeight*imageWidth, by: 1){

                pointArray.removeAll()

                //for arrayNumber in stride(from: 0, to: dataFromAllTheImagesToCombine.count, by: 1){
                for floatingArray in dataFromAllTheImagesToCombine {
                    pointArray.append(floatingArray[pixel])
                }

                mean.append(pointArray.mean)
                if (pointArray.count > 1){

                    deviation.append(pointArray.stdev!)
                }
                else{
                    deviation.append(pointArray.stdevp!)
                }

            }


            // Sum if the pixel is within numberOfStandardDeviationsAway from the mean

            for pixel in stride(from: 0, to: imageHeight*imageWidth, by: 1){

                var sumCounter = 0

                for floatingArray in dataFromAllTheImagesToCombine {

                    if (abs(floatingArray[pixel]-mean[pixel]) <= Float(numberOfStandardDeviationsAway)*deviation[pixel] ){

                        sumCounter += 1

                        summedFloatArray[pixel] = (summedFloatArray[pixel]*Float(sumCounter - 1) + floatingArray[pixel])/Float(sumCounter)




                    }


                }

    //            print(summedFloatArray[pixel], sumCounter )
                //summedFloatArray[pixel] *= 10
            }

            return (summedFloatArray)
        }

}


