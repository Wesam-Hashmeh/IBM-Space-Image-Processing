
//
//  StarCoordinateLocator.swift
//  FITSDocument
//
//  Created by Jakob Lockard on 3/10/22.
//

import Foundation
import SwiftUI
import simd
import UniformTypeIdentifiers
import FITS
import FITSKit
import Accelerate

class StarCoordinateLocator :NSObject {
    
    @State var alignedImage :CGImage?
    func findTheStars(imageData: [Float], width: Int, height: Int, relativePeakLimit: Float) -> [xy_coord]{
        
        let maximumIntensity = imageData.max()
        
        print("Max intensity found ", maximumIntensity ?? 0.0)
        
        //Create Normalized Image
        
        var normalizedData :[Float] = []
        
        for item in imageData{
            
            normalizedData.append(item/maximumIntensity!)
        }
        
        var chunkSize = 17
        
        if (((width/100)%2) != 0){
            
            chunkSize = Int(width/100)
        }
        else {
            
            chunkSize = Int(width/100) + 1
        }
        
        if (chunkSize < 11) {
            
            chunkSize = 11
        }
        
        print("chunkSize =", chunkSize)
        let halfChunkSizeRoundedDown = Int( floor((Double(chunkSize)/2.0)))
        
        //var centerX = 0
        //var centerY = 0
        
        var centroidCoordinates :[xy_coord] = []
        
        
        //Identifying points where a gaussian fit will be attempted (does not do yet)
        
        print("Running preliminary star finder loops")
        
        for centerY in stride(from: halfChunkSizeRoundedDown, to: (height - halfChunkSizeRoundedDown), by: chunkSize) {
            
            for centerX in stride(from: halfChunkSizeRoundedDown, to: (width - halfChunkSizeRoundedDown), by: chunkSize) {
                
                //Create the check array
                var testArray :[Float] = []
                
                for y in stride(from: centerY-halfChunkSizeRoundedDown, through: centerY+halfChunkSizeRoundedDown, by: 1){
                    
                    for x in stride(from: centerX-halfChunkSizeRoundedDown, through: centerX+halfChunkSizeRoundedDown, by: 1){
                        
                        testArray.append(imageData[x + y*width])
                        
                        
                    }
                    
                    
                }
                
                let returnedCoordinates = findMaximumValueInChunk(image: testArray, centerX: centerX, centerY: centerY, chunkSize: chunkSize, relativePeakLimit: relativePeakLimit)
                
                if (returnedCoordinates.y > 0.0) {
                    
                    centroidCoordinates.append(returnedCoordinates)
                    
                }
                
            }
        }
        
        print("Found ", centroidCoordinates.count, "places to check a gaussian fit")
        
        return(centroidCoordinates)
        
    }
    
    func rotateAndTranslateImage(_ imageData: inout [Float], _ transformedOutput: inout [Float], _ sourceRowBytes: Int, deltaX: Float, deltaY: Float, angle: Float, dataHeight: UInt, dataWidth: UInt)-> CGImage? {
            imageData.withUnsafeMutableBufferPointer {pointerToImageFloats in
                transformedOutput.withUnsafeMutableBufferPointer {pointToTransformedData in
                    
                    var newDeltaX = deltaX
                    var newDeltaY = deltaY
                    
                    //newDeltaX = -5.0
                    
                    var rawvImageBuffer :vImage_Buffer = vImage_Buffer(data: pointerToImageFloats.baseAddress, height: vImagePixelCount(Int(dataHeight)), width: vImagePixelCount(Int(dataWidth)), rowBytes: sourceRowBytes)
                    
                    var finalvImageBuffer = vImage_Buffer(data: pointToTransformedData.baseAddress, height: vImagePixelCount(Int(dataHeight)), width: vImagePixelCount(Int(dataWidth)), rowBytes: sourceRowBytes)
                    
                   // let radians = CGFloat(45.0 * Float.pi/180.0)
                    
                    let cgTransform = CGAffineTransform.identity
                    //.translatedBy(x: 124,
                    //              y: -1222)
                    //.translatedBy(x: CGFloat(Int(dataWidth!)-1764), y: -571)
                        .translatedBy(x: CGFloat(newDeltaX), y: CGFloat(-newDeltaY))
                        .rotated(by: CGFloat(angle))
                    
                    
                    
                    var transformationMatrix :vImage_AffineTransform = vImage_AffineTransform(a: Float(cgTransform.a), b: Float(cgTransform.b), c: Float(cgTransform.c), d: Float(cgTransform.d), tx: Float(cgTransform.tx), ty: Float(cgTransform.ty))
                    
                    let backgroundColor :Pixel_F = 0.0
                    
                    let err = vImageAffineWarp_PlanarF(&rawvImageBuffer, &finalvImageBuffer, nil, &transformationMatrix, backgroundColor, vImage_Flags(kvImageBackgroundColorFill))
                    
                    
                }
            }
            
            return returningCGImage(data: transformedOutput, width: Int(dataWidth), height: Int(dataHeight), rowBytes: sourceRowBytes)
        }
    
    func mostFrequent<T: Hashable>(array: [T]) -> (value: T, count: Int)? {
        
        let counts = array.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        
        if let (value, count) = counts.max(by: { $0.1 < $1.1 }) {
            return (value, count)
        }
        
        // array was empty
        return nil
    }
    
    func findAngleAndDeltas(matchingPointsArray:[(primary: simd_float3,  alignment: simd_float3)], imageSize: (width: Int, height:Int)) -> (angle: Float, deltaX: Float, deltaY: Float, failed: Bool){
        
        
        //var alignmentParametersArray :[(angle: Float, deltaX: Float, deltaY: Float)] = []
        var angleArray :[Float] = []
        var deltaXArray :[Float] = []
        var deltaYArray :[Float] = []
        
        //var goodAngleArray :[Float] = []
        //var goodDeltaXArray :[Float] = []
        //var goodDeltaYArray :[Float] = []
        
        if(matchingPointsArray[0].primary == matchingPointsArray[0].alignment){
            
            return (angle: Float(0.0), deltaX: Float(0.0), deltaY: Float(0.0), failed: false )
        }
        
        var alignmentArray :[(primary:(point1: simd_float3, point2: simd_float3), alignment: ((point1: simd_float3, point2: simd_float3)))] = []
        
        for firstPoint in stride(from: 0, to: matchingPointsArray.count - 1, by: 1){
            
            //var maxLength :Float = -10000.0
            let firstPrimaryPoint = matchingPointsArray[firstPoint].primary
            let firstAlignmentPoint = matchingPointsArray[firstPoint].alignment
            var secondPrimaryPoint = matchingPointsArray[firstPoint].primary
            var secondAlignmentPoint = matchingPointsArray[firstPoint].alignment
            
            for secondPoint in stride(from: firstPoint+1, to: matchingPointsArray.count, by: 1){
                
                //                let length = simd_distance(matchingPointsArray[firstPoint].primary, matchingPointsArray[secondPoint].primary)
                //
                //                if (length > maxLength ){
                //
                //                    secondAlignmentPoint = matchingPointsArray[secondPoint].alignment
                //                    secondPrimaryPoint = matchingPointsArray[secondPoint].primary
                //
                //
                secondAlignmentPoint = matchingPointsArray[secondPoint].alignment
                secondPrimaryPoint = matchingPointsArray[secondPoint].primary
                
                
                
                alignmentArray.append((primary:(point1: firstPrimaryPoint, point2: secondPrimaryPoint), alignment: ((point1: firstAlignmentPoint, point2: secondAlignmentPoint))))
                
                
            }
            
            
        }
        
        for item in alignmentArray {
            
            //let primaryVector = primaryVectorArray[1] - primaryVectorArray[0]
            
            let primaryVector = item.primary.point2 - item.primary.point1
            
            print("lengthofPrimary", simd_length(primaryVector))
            
            
            //let alignmentVector = alignmentVectorArray[1] - alignmentVectorArray[0]
            
            let alignmentVector = item.alignment.point2 - item.alignment.point1
            
            print("lengthofAlignment", simd_length(alignmentVector))
            
            let dotProduct = simd_dot(simd_precise_normalize(primaryVector), simd_precise_normalize(alignmentVector))
            
            let angle = returnAngle(passedDotProduct: dotProduct, primaryVector: primaryVector, alignmentVector: alignmentVector)
            
            //            let deltaX = maximumVector.primary.point1.x * cos(angle) - maximumVector.primary.point1.y * sin(angle) - maximumVector.alignment.point1.x
            //
            //            let deltaY = maximumVector.primary.point1.x * sin(angle) + maximumVector.primary.point1.y * cos(angle) - maximumVector.alignment.point1.y
            
            
            //Address the stupid way that Apple currently does images. Bottom left corner is (0, maxHeight)
            
            let dataX_1 = item.alignment.point1.x
            let dataY_1 = item.alignment.point1.y
            
            let rotationX_1 = dataX_1
            let rotationY_1 = Float(imageSize.height) - dataY_1
            
            let newX_1 = rotationX_1 * cos(angle) - rotationY_1 * sin(angle)
            let newY_1 = rotationX_1 * sin(angle) + rotationY_1 * cos(angle)
            
            let dataX_2 = item.alignment.point2.x
            let dataY_2 = item.alignment.point2.y
            
            let rotationX_2 = dataX_2
            let rotationY_2 = Float(imageSize.height) - dataY_2
            
            let newX_2 = rotationX_2 * cos(angle) - rotationY_2 * sin(angle)
            let newY_2 = rotationX_1 * sin(angle) + rotationY_2 * cos(angle)
            
            let finalY_1 = Float(imageSize.height) - newY_1
            let finalY_2 = Float(imageSize.height) - newY_2
            
            
            let deltaX1 = newX_1 - item.primary.point1.x
            
            let deltaY1 = finalY_1 - item.primary.point1.y
            
            let deltaX2 = newX_2 - item.primary.point2.x
            
            let deltaY2 = finalY_2 - item.primary.point2.y
            
            //print("Angle", angle, "DeltaX", deltaX, "DeltaY", deltaY)
            
            let deltaX = (deltaX2+deltaX1)/2.0
            let deltaY = (deltaY2+deltaY1)/2.0
            
            angleArray.append(angle)
            deltaXArray.append(deltaX)
            deltaYArray.append(deltaY)
            
            //alignmentParametersArray.append((angle: angle, deltaX: deltaX, deltaY: deltaY))
        }
        
        //        var sortedDeltaX = deltaXArray
        //        var smallSortedDeltaXArray :[Float] = []
        //
        //        sortedDeltaX = deltaXArray.sorted{$0 < $1 }
        //
        //        var sortedMean :Float = sortedDeltaX.mean
        //        var oldSortedMean :Float = -200000000.0
        //
        //        while (abs(sortedMean-oldSortedMean) > 1) {
        //
        //            for counter in stride(from: 0, to: (sortedDeltaX.count - 1), by: 1){
        //
        //                if (abs(sortedDeltaX[counter] - sortedDeltaX[counter+1]) < 1){
        //
        //                    smallSortedDeltaXArray.append(sortedDeltaX[counter])
        //
        //                }
        //
        //            }
        //            sortedDeltaX = smallSortedDeltaXArray
        //
        //            oldSortedMean = sortedMean
        //            smallSortedDeltaXArray.removeAll()
        //
        //            sortedMean = sortedDeltaX.mean
        //
        //        }
        
        //        var angleMean = angleArray.mean
        //        var angleStd = angleArray.stdevp
        //        var deltaXMean = deltaXArray.mean
        //        var deltaXStd = deltaXArray.stdevp
        //        var deltaYMean = deltaYArray.mean
        //        var deltaYStd = deltaYArray.stdevp
        
        //        for counter in stride(from: 0, to: deltaXArray.count, by: 1){
        //
        //            if (abs(deltaXArray[counter] - sortedMean) < 1){
        //
        //                goodDeltaXArray.append(deltaXArray[counter])
        //                goodDeltaYArray.append(deltaYArray[counter])
        //
        //                if abs(angleArray[counter]) <= 0.1*Float.pi/180.0{
        //
        //                    goodAngleArray.append(Float(0.0))
        //                }
        //                else{
        //                    goodAngleArray.append(angleArray[counter])
        //                }
        //
        //
        //            }
        //
        //
        //        }
        
        //        let sortedFinalDeltaX = goodDeltaXArray.sorted{$0 < $1 }
        //        let sortedFinalDeltaY = goodDeltaYArray.sorted{$0 < $1 }
        //        let sortedFinalAngle = goodAngleArray.sorted{$0 < $1 }
        
        
        var medianX :Float = 0.0
        var medianY :Float = 0.0
        var medianAngle :Float = 0.0
        
        //        let counterX = sortedFinalDeltaX.count/2
        //
        //        if counterX%2 == 0 {
        //
        //
        //
        //            medianX = (sortedFinalDeltaX[counterX] + sortedFinalDeltaX[counterX - 1])/2.0
        //        }
        //        else{
        //
        //            medianX = (sortedFinalDeltaX[counterX] )
        //
        //        }
        //
        //        let counterY = sortedFinalDeltaY.count/2
        //
        //        if counterY%2 == 0 {
        //
        //            medianY = (sortedFinalDeltaY[counterY] + sortedFinalDeltaY[counterY - 1])/2.0
        //        }
        //        else{
        //
        //            medianY = (sortedFinalDeltaY[counterY] )
        //
        //        }
        //
        //        let counterAngle = sortedFinalAngle.count/2
        //
        //        if counterAngle%2 == 0 {
        //
        //            medianAngle = (sortedFinalAngle[counterY] + sortedFinalAngle[counterY - 1])/2.0
        //        }
        //        else{
        //
        //            medianAngle = (sortedFinalAngle[counterY] )
        //
        //        }
        
        var failed = false
        
        if deltaXArray.count != 0 && deltaYArray.count != 0 && angleArray.count != 0 {
            
            medianX = calculateMedian(array: sortTheArray(array: deltaXArray))
            medianY = calculateMedian(array: sortTheArray(array: deltaYArray))
            medianAngle = calculateMedian(array: sortTheArray(array: angleArray))
            
        }
        else{
            
            failed = true
        }
        
        
        
        
        return((angle: medianAngle, deltaX: -medianX, deltaY: -medianY, failed: failed) )
        //        return((angle: Float(0.000), deltaX: goodDeltaXArray.max()!, goodDeltaYArray.max()!) )
        
    }
    
    func findMatchingPoints(matchedTriangles: [(primary: (pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float), alignment: (pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float))]) -> [(primary: simd_float3,  alignment: simd_float3)] {
        
        //var numberOfPoints = 0
        
        var primaryPoints :[simd_float3] = []
        
        for item in matchedTriangles{
            
            primaryPoints.append(item.primary.pointA)
            primaryPoints.append(item.primary.pointB)
            primaryPoints.append(item.primary.pointC)
            
            
        }
        
        //get rid of the duplicate points
        let noDuplicatePrimaryPoints = primaryPoints.reduce(into: [simd_float3]()) {
            if !$0.contains($1) {
                $0.append($1)
            } else {
                print("Found duplicate: \($1)")
            }
        }
        
        var alignmentPoints :[simd_float3] = []
        
        var matchedPoints :[(primary: simd_float3, alignment: [simd_float3])] = []
        
        for item in noDuplicatePrimaryPoints{
            
            for dataInAlignmentPoints in matchedTriangles{
                
                if ((item == dataInAlignmentPoints.primary.pointA)){
                    
                    alignmentPoints.append(dataInAlignmentPoints.alignment.pointA)
                    
                }
                else if (item == dataInAlignmentPoints.primary.pointB){
                    
                    
                    alignmentPoints.append(dataInAlignmentPoints.alignment.pointB)
                    
                } else if (item == dataInAlignmentPoints.primary.pointC){
                    
                    alignmentPoints.append(dataInAlignmentPoints.alignment.pointC)
                    
                }
                
                
            }
            
            matchedPoints.append((primary: item, alignment: alignmentPoints))
            
            alignmentPoints.removeAll()
            
            
            
        }
        
        var preliminaryEquivalentPointsArray :[(primary: simd_float3,  alignment: simd_float3)] = []
        var equivalentPointsArray :[(primary: simd_float3,  alignment: simd_float3)] = []
        
        for item in matchedPoints{
            
            
            if let result = mostFrequent(array: item.alignment) {
                //print("(result.value) occurs (result.count) times")
                
                if (Float(result.count)/Float(item.alignment.count) > 0.1){
                    
                    preliminaryEquivalentPointsArray.append((primary: item.primary, alignment: result.value))
                    
                }
                
                
            }
            
            
            
            
            
        }
        
        
        
        
        
        //
        //        var sortedPrimary = primary.sorted{$0.length > $1.length }
        //        var sortedAlignment = alignment.sorted{$0.length > $1.length }
        //
        //        for primaryItem in sortedPrimary{
        //
        //            for alignmentItem in sortedAlignment{
        //
        //                if abs(alignmentItem.length - primaryItem.length) < 3.0{
        //
        //                    numberOfPoints += 1
        //
        //                    alignmentPointsArray.append((primary: primaryItem, alignment: alignmentItem))
        //
        //                    }
        //
        //                if numberOfPoints == 20 {
        //
        //                        break
        //
        //                }
        //
        //
        //
        //            }
        //
        //            if numberOfPoints == 20 {
        //
        //                break
        //            }
        //
        //
        //
        //        }
        
        // let returnPoints = alignmentPointsArray[0]
        
        //return returnPoints
        
        var deltaX :[Float] = []
        var deltaY :[Float] = []
        
        //Verify preliminaryEquivalentPointsArray
        
        for item in preliminaryEquivalentPointsArray{
            
            
            deltaX.append(abs(item.primary.x-item.alignment.x))
            deltaY.append(abs(item.primary.y-item.alignment.y))
            
        }
        
        //        let sortedDeltaX = deltaX.sorted{$0 < $1 }
        //        let sortedDeltaY = deltaY.sorted{$0 < $1 }
        //
        //        var medianX :Float = 0.0
        //        var medianY :Float = 0.0
        
        let medianX = calculateMedian(array: sortTheArray(array: deltaX))
        let medianY = calculateMedian(array: sortTheArray(array: deltaY))
        
        //        let counterX = sortedDeltaX.count/2
        //
        //        if counterX%2 == 0 {
        //
        //
        //
        //            medianX = (sortedDeltaX[counterX] + sortedDeltaX[counterX - 1])/2.0
        //        }
        //        else{
        //
        //            medianX = (sortedDeltaX[counterX] )
        //
        //        }
        //
        //        let counterY = sortedDeltaY.count/2
        //
        //        if counterY%2 == 0 {
        //
        //            medianY = (sortedDeltaY[counterY] + sortedDeltaY[counterY - 1])/2.0
        //        }
        //        else{
        //
        //            medianY = (sortedDeltaY[counterY] )
        //
        //        }
        
        
        
        for counter in stride(from: 0, to: preliminaryEquivalentPointsArray.count, by: 1){
            
            //            let pointDeltaX = abs(preliminaryEquivalentPointsArray[counter].primary.x - preliminaryEquivalentPointsArray[counter].alignment.x)
            //            let pointDeltaY = abs(preliminaryEquivalentPointsArray[counter].primary.y - preliminaryEquivalentPointsArray[counter].alignment.y)
            
            //            let xCheck = (abs(deltaX[counter] - pointDeltaX))
            //            let yCheck = (abs(deltaY[counter] - pointDeltaY))
            
            let xCheck = abs(deltaX[counter]-medianX)
            let yCheck = abs(deltaY[counter]-medianY)
            
            if ((xCheck <= 5.0) && ( yCheck <= 5.0)){
                
                equivalentPointsArray.append(preliminaryEquivalentPointsArray[counter])
            }
            
        }
        
        return equivalentPointsArray
    }
    
    func returnAngle(passedDotProduct: Float, primaryVector: simd_float3, alignmentVector: simd_float3)->(Float){
        
        var dotProduct = passedDotProduct
        
        if dotProduct >= 1.0{
            
            dotProduct = 0.9999999
        }else if dotProduct <= -1.0{
            
            dotProduct = -0.9999999
            
        }
        var angle = acos(dotProduct)
        
        if abs(angle) <= 0.05*Float.pi/180.0{
            
            angle = (Float(0.0))
        }
        
        let cross = simd_cross(primaryVector, alignmentVector)
        
        print(angle, cross)
        
        if (cross.z < 0.0){
            
            angle *= -1.0
        }
        
        return angle
        
    }
    
    
    func alignTriangles(matchedTriangles: [(primary: (pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float), alignment: (pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float))])->[(primary: (pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float), alignment: (pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float))]{
        
        
        //var alignmentParametersArray :[(angle: Float, deltaX: Float, deltaY: Float)] = []
        var angleArray :[Float] = []
        //var deltaXArray :[Float] = []
        //var deltaYArray :[Float] = []
        
        var reducedTriangles :[(primary: (pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float), alignment: (pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float))] = []
        
        for item in matchedTriangles{
            
            //let primaryVector = primaryVectorArray[1] - primaryVectorArray[0]
            
            let primaryVectorAB = item.primary.pointA - item.primary.pointB
            let primaryVectorAC = item.primary.pointA - item.primary.pointC
            let primaryVectorBC = item.primary.pointB - item.primary.pointC
            
            
            //let alignmentVector = alignmentVectorArray[1] - alignmentVectorArray[0]
            
            let alignmentVectorAB = item.alignment.pointA - item.alignment.pointB
            let alignmentVectorAC = item.alignment.pointA - item.alignment.pointC
            let alignmentVectorBC = item.alignment.pointB - item.alignment.pointC
            
            let dotProductAB = simd_dot(simd_precise_normalize(primaryVectorAB), simd_precise_normalize(alignmentVectorAB))
            let dotProductAC = simd_dot(simd_precise_normalize(primaryVectorAC), simd_precise_normalize(alignmentVectorAC))
            let dotProductBC = simd_dot(simd_precise_normalize(primaryVectorBC), simd_precise_normalize(alignmentVectorBC))
            
            let angleAB = returnAngle(passedDotProduct: dotProductAB, primaryVector: primaryVectorAB, alignmentVector: alignmentVectorAB)
            let angleAC = returnAngle(passedDotProduct: dotProductAC, primaryVector: primaryVectorAC, alignmentVector: alignmentVectorAC)
            let angleBC = returnAngle(passedDotProduct: dotProductBC, primaryVector: primaryVectorBC, alignmentVector: alignmentVectorBC)
            
            
            let deltaXAB = primaryVectorAB.x * cos(angleAB) - primaryVectorAB.y * sin(angleAB) - alignmentVectorAB.x
            
            let deltaYAB = primaryVectorAB.x * sin(angleAB) + primaryVectorAB.y * cos(angleAB) - alignmentVectorAB.y
            
            let deltaXAC = primaryVectorAC.x * cos(angleAC) - primaryVectorAC.y * sin(angleAC) - alignmentVectorAC.x
            
            let deltaYAC = primaryVectorAC.x * sin(angleAC) + primaryVectorAC.y * cos(angleAC) - alignmentVectorAC.y
            
            let deltaXBC = primaryVectorBC.x * cos(angleBC) - primaryVectorBC.y * sin(angleBC) - alignmentVectorBC.x
            
            let deltaYBC = primaryVectorBC.x * sin(angleBC) + primaryVectorBC.y * cos(angleBC) - alignmentVectorBC.y
            
            
            print("AngleAB", angleAB, "AngleAC", angleAC, "AngleBC", angleBC)
            print("DeltaXAB", deltaXAB, "DeltaYAB", deltaYAB, "DeltaXAC", deltaXAC, "DeltaYAC", deltaYAC, "DeltaXBC", deltaXBC, "DeltaYBC", deltaYBC)
            
            //print("Angle", angle, "DeltaX", deltaX, "DeltaY", deltaY)
            
            angleArray.append(angleAB)
            angleArray.append(angleAC)
            angleArray.append(angleBC)
            //            deltaXArray.append(deltaX)
            //            deltaYArray.append(deltaY)
            
            //alignmentParametersArray.append((angle: angle, deltaX: deltaX, deltaY: deltaY))
            
            
            
        }
        
        let angleArrayDev = angleArray.stdev!*2.0
        let angleArrayMean = angleArray.mean
        
        print("The average angle is", angleArray.mean, "with a deviation of", angleArray.stdev!)
        
        var angleCounter = 0
        
        for item in matchedTriangles{
            
            
            if ((abs(angleArray[angleCounter] - angleArrayMean) < angleArrayDev) && (abs(angleArray[angleCounter+1] - angleArrayMean) < angleArrayDev) && (abs(angleArray[angleCounter+2] - angleArrayMean) < angleArrayDev)){
                
                reducedTriangles.append(item)
                
                
                
            }
            
            
            
            angleCounter += 3
            
            
        }
        
        return reducedTriangles
    }
    
    
    func findMatchingTriangles(primary: [(pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float)], alignment: [(pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float)]) -> [(primary: (pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float), alignment: (pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float))]{
        
        
        var matchedTriangles :[(primary: (pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float), alignment: (pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float))] = []
        
        let checkAngleCriteria :Float = 2.0*Float.pi/180.0
        let checkDivisionCriteria :Float = 0.001
        
        for primaryTriangle in primary {
            
            for alignmentTriangle in alignment{
                
                
                if(abs(primaryTriangle.normalizedPerimeter - alignmentTriangle.normalizedPerimeter) < 0.005){
                    
                    if ((abs(primaryTriangle.AB_angle - alignmentTriangle.AB_angle) < checkAngleCriteria ) && (abs(primaryTriangle.AC_angle - alignmentTriangle.AC_angle) < checkAngleCriteria ) && (abs(primaryTriangle.BC_angle - alignmentTriangle.BC_angle) < checkAngleCriteria )){
                        
                        let divisionAC = primaryTriangle.AC_length/alignmentTriangle.AC_length
                        let divisionAB = primaryTriangle.AB_length/alignmentTriangle.AB_length
                        let divisionBC = primaryTriangle.BC_length/alignmentTriangle.BC_length
                        
                        if ((abs(divisionAC-divisionAB)<checkDivisionCriteria) && (abs(divisionBC-divisionAB)<checkDivisionCriteria) && (abs(divisionAC-divisionBC)<checkDivisionCriteria)) {
                            
                            let differenceAx = abs(primaryTriangle.pointA.x - alignmentTriangle.pointA.x)
                            let differenceAy = abs(primaryTriangle.pointA.y - alignmentTriangle.pointA.y)
                            let differenceBx = abs(primaryTriangle.pointB.x - alignmentTriangle.pointB.x)
                            let differenceBy = abs(primaryTriangle.pointB.y - alignmentTriangle.pointB.y)
                            let differenceCx = abs(primaryTriangle.pointC.x - alignmentTriangle.pointC.x)
                            let differenceCy = abs(primaryTriangle.pointC.y - alignmentTriangle.pointC.y)
                            
                            
                            
                            
                            let largest = max(primaryTriangle.AB_length, primaryTriangle.AC_length, primaryTriangle.BC_length)/2.0
                            
                            
                            if (differenceAx < largest && differenceAy < largest && differenceBx < largest && differenceBy < largest && differenceCx < largest && differenceCy < largest){
                                
                                
                                matchedTriangles.append((primary: primaryTriangle, alignment: alignmentTriangle))
                            }
                            
                            
                        }
                        
                        
                        
                        
                        
                    }
                    
                }
                
                
            }
            
            
        }
        
        return matchedTriangles
        
        
    }
    
    func findMaximumValueInChunk(image: [Float], centerX: Int, centerY: Int, chunkSize: Int, relativePeakLimit: Float ) -> xy_coord {
        
        let max = image.max()
        
        if ((max! <= relativePeakLimit) || (max! >= 0.95 )){
            
            let returnCoordinate = xy_coord(x: -1.0, y: -1.0)
            
            return returnCoordinate
        }
        
        let deviation = image.stdev
        
        if deviation! < (relativePeakLimit*0.1) {
            
            //let returnCoordinate = xy_coord(x: Double(centerX), y: Double(centerY))
            
            let returnCoordinate = xy_coord(x: -1.0, y: -1.0)
            
            return returnCoordinate
            
        }
        
        let halfChunkSizeRoundedDown :Int = Int(floor((Double(chunkSize)/2.0)))
        
        //var chunkAverage = 0.0
        
        //printf("%f\n",valueCenter);
        
        //var isBiggest = true
        //var isPeak = false
        
        var x = 0
        var y = 0
        
        //Checking for the maximum value
        
        for deltaY in stride(from: -halfChunkSizeRoundedDown, to: (halfChunkSizeRoundedDown), by: 1) {
            
            for deltaX in stride(from: -halfChunkSizeRoundedDown, to: halfChunkSizeRoundedDown, by: 1) {
                
                let valueChecking = image[(deltaX + halfChunkSizeRoundedDown) + (deltaY + halfChunkSizeRoundedDown)*chunkSize]
                
                if (abs(valueChecking-max!) < (max!.ulp*5) ) {
                    
                    x = centerX + deltaX
                    y = centerY + deltaY
                    
                    break
                }
            }
        }
        
        
        let returnCoordinate = xy_coord(x: Double(x), y: Double(y))
        
        return returnCoordinate
    }
    
    func makeTriangleFromXYZ(points: (point1: simd_float3, point2: simd_float3, point3: simd_float3)) -> (pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float){
        
        //Triangles are being defined in a particular way such that the point that comes to be called "A" is oppposite the longest side
        //And the point that comes to be called "C" is opposite the shortest side
        //This chunk of code does this assignment
        var output :(pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float)
        
        //double initAB, initAC, initBC;
        //initAB = getLength((struct xy_coord)initA, initB);
        //initAC = getLength(initA, initC);
        //initBC = getLength(initB, initC);
        
        let initialAB = points.point2 - points.point1
        let initialAC = points.point3 - points.point1
        let initialBC = points.point3 - points.point2
        
        
        let lengthAB = simd_length(initialAB)
        let lengthAC = simd_length(initialAC)
        let lengthBC = simd_length(initialBC)
        
        //3!=6 cases
        
        //initAB long
        if (lengthAB>lengthAC && lengthAB>lengthBC) {
            //initBC short
            if (lengthAC>lengthBC){
                output.pointA=points.point3
                output.pointB=points.point2
                output.pointC=points.point1
                output.AB_length=lengthBC
                output.AC_length=lengthAC
                output.BC_length=lengthAB
                output.AB_angle = acos(simd_dot(simd_precise_normalize(output.pointA), simd_precise_normalize(output.pointB)))
                output.AC_angle = acos(simd_dot(simd_precise_normalize(output.pointA), simd_precise_normalize(output.pointC)))
                output.BC_angle = acos(simd_dot(simd_precise_normalize(output.pointB), simd_precise_normalize(output.pointC)))
                output.normalizedPerimeter = (lengthAB+lengthBC+lengthAC)/lengthAB
                
            }
            //initAC short or equal
            else {
                output.pointA=points.point3
                output.pointB=points.point1
                output.pointC=points.point2
                output.AB_length=lengthAC
                output.AC_length=lengthBC
                output.BC_length=lengthAB
                output.AB_angle = acos(simd_dot(simd_precise_normalize(output.pointA), simd_precise_normalize(output.pointB)))
                output.AC_angle = acos(simd_dot(simd_precise_normalize(output.pointA), simd_precise_normalize(output.pointC)))
                output.BC_angle = acos(simd_dot(simd_precise_normalize(output.pointB), simd_precise_normalize(output.pointC)))
                output.normalizedPerimeter = (lengthAB+lengthBC+lengthAC)/lengthAB
            }
        }
        //initAC long
        else if (lengthAC>lengthAB && lengthAC>lengthBC) {
            //initBC short
            if (lengthAB>lengthBC){
                output.pointA=points.point2
                output.pointB=points.point3
                output.pointC=points.point1
                output.AB_length=lengthBC
                output.AC_length=lengthAB
                output.BC_length=lengthAC
                output.AB_angle = acos(simd_dot(simd_precise_normalize(output.pointA), simd_precise_normalize(output.pointB)))
                output.AC_angle = acos(simd_dot(simd_precise_normalize(output.pointA), simd_precise_normalize(output.pointC)))
                output.BC_angle = acos(simd_dot(simd_precise_normalize(output.pointB), simd_precise_normalize(output.pointC)))
                output.normalizedPerimeter = (lengthAB+lengthBC+lengthAC)/lengthAC
            }
            //initAB short or equal
            else {
                output.pointA=points.point2
                output.pointB=points.point1
                output.pointC=points.point3
                output.AB_length=lengthAB
                output.AC_length=lengthBC
                output.BC_length=lengthAC
                output.AB_angle = acos(simd_dot(simd_precise_normalize(output.pointA), simd_precise_normalize(output.pointB)))
                output.AC_angle = acos(simd_dot(simd_precise_normalize(output.pointA), simd_precise_normalize(output.pointC)))
                output.BC_angle = acos(simd_dot(simd_precise_normalize(output.pointB), simd_precise_normalize(output.pointC)))
                output.normalizedPerimeter = (lengthAB+lengthBC+lengthAC)/lengthAC
            }
        }
        //initBC long
        else if (lengthBC>lengthAB && lengthBC>lengthAC) {
            //initAB short
            if (lengthAC>lengthAB){
                output.pointA=points.point1
                output.pointB=points.point2
                output.pointC=points.point3
                output.AB_length=lengthAB
                output.AC_length=lengthAC
                output.BC_length=lengthBC
                output.AB_angle = acos(simd_dot(simd_precise_normalize(output.pointA), simd_precise_normalize(output.pointB)))
                output.AC_angle = acos(simd_dot(simd_precise_normalize(output.pointA), simd_precise_normalize(output.pointC)))
                output.BC_angle = acos(simd_dot(simd_precise_normalize(output.pointB), simd_precise_normalize(output.pointC)))
                output.normalizedPerimeter = (lengthAB+lengthBC+lengthAC)/lengthBC
            }
            //initAC short or equal
            else{
                output.pointA=points.point1
                output.pointB=points.point3
                output.pointC=points.point2
                output.AB_length=lengthAC
                output.AC_length=lengthAB
                output.BC_length=lengthBC
                output.AB_angle = acos(simd_dot(simd_precise_normalize(output.pointA), simd_precise_normalize(output.pointB)))
                output.AC_angle = acos(simd_dot(simd_precise_normalize(output.pointA), simd_precise_normalize(output.pointC)))
                output.BC_angle = acos(simd_dot(simd_precise_normalize(output.pointB), simd_precise_normalize(output.pointC)))
                output.normalizedPerimeter = (lengthAB+lengthBC+lengthAC)/lengthBC
            }
        }
        
        //All side lengths are equal, this probably shouldn't occur since the data should be "fuzzy"
        //Actual assignment is arbitrary in this case
        else {
            output.pointA=points.point1
            output.pointB=points.point2
            output.pointC=points.point3
            output.AB_length=lengthAB
            output.AC_length=lengthAC
            output.BC_length=lengthBC
            output.AB_angle = acos(simd_dot(simd_precise_normalize(output.pointA), simd_precise_normalize(output.pointB)))
            output.AC_angle = acos(simd_dot(simd_precise_normalize(output.pointA), simd_precise_normalize(output.pointC)))
            output.BC_angle = acos(simd_dot(simd_precise_normalize(output.pointB), simd_precise_normalize(output.pointC)))
            output.normalizedPerimeter = (lengthAB+lengthBC+lengthAC)/lengthAC
            
            print("Note: Triangle is apparently equilateral. This might indicate a problem\n");
        }
        
        return output
        
    }
    
    func findTrianglesInImage(points: (original: [simd_float3], normalized: [simd_float3]))->[(pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float)]{
        
        //At this point the centroids have been identified
        //Now to generate the centroid triangles
        
        var centroidTriangles :[(pointA: simd_float3, pointB: simd_float3, pointC: simd_float3, AB_length: Float, AC_length: Float, BC_length: Float, AB_angle: Float, AC_angle: Float, BC_angle: Float, normalizedPerimeter: Float)] = []
        
        let numberOfStarsFound = points.original.count
        
        //int index=0;
        let numberOfCentroidTriangles = Int(Float(numberOfStarsFound)*(Float(numberOfStarsFound-Int(1.0)))*(Float(numberOfStarsFound-Int(2.0))/6.0))
        
        print("Generating %d triangles for the located centroids",numberOfCentroidTriangles)
        
        for firstPointCounter in stride(from: 0, to: numberOfStarsFound - 2, by: 1){
            
            let firstPoint = points.original[firstPointCounter]
            
            for secondPointCounter in stride(from: firstPointCounter + 1, to: numberOfStarsFound - 1, by: 1){
                
                let secondPoint = points.original[secondPointCounter]
                
                for thirdPointCounter in stride(from: secondPointCounter + 1, to: numberOfStarsFound, by: 1){
                    
                    let thirdPoint = points.original[thirdPointCounter]
                    
                    centroidTriangles.append(makeTriangleFromXYZ(points: (firstPoint, secondPoint, thirdPoint)))
                    
                }
            }
        }
        
        print("Centroid triangle generation complete")
        
        centroidTriangles = centroidTriangles.sorted{$0.normalizedPerimeter > $1.normalizedPerimeter }
        
        return centroidTriangles
        
    }
    
    func getLengthVectorsInImage(points: [simd_float3]) -> [(point1: simd_float3, point2: simd_float3, length: Float)] {
        
        
        var pointsAndLengthArray :[(point1: simd_float3, point2: simd_float3, length: Float)] = []
        
        for i in stride(from: 0, to: (points.count - 1), by: 1){
            
            for j in stride(from: i+1, to: points.count, by: 1){
                
                let pointsAndLength = (point1: points[i], point2: points[j], length: simd_length(points[j]-points[i]))
                
                pointsAndLengthArray.append(pointsAndLength)
                
            }
            
        }
        
        return (pointsAndLengthArray)
        
        
    }
    
    func convertCoordinatesTosimdForTriangleSearch(coordinates: [xy_coord]) -> (original: [simd_float3], normalized: [simd_float3]){
        
        var simdCentroidCoordinates :[simd_float3] = []
        var normalizedsimdCentroidCoordinates :[simd_float3] = []
        
        for item in coordinates{
            
            simdCentroidCoordinates.append(simd_make_float3(Float(item.x), Float(item.y), 0.0 ))
            normalizedsimdCentroidCoordinates.append(simd_precise_normalize(simdCentroidCoordinates.last!))
        }
        
        
        return (original: simdCentroidCoordinates, normalized: normalizedsimdCentroidCoordinates)
        
        
    }
    
    func shouldAttemptGaussianFitAtThisPoint(image: [Float], centerX: Int, centerY: Int, width: Int, height: Int, chunkSize: Int, relativePeakLimit: Double ) -> Bool {
        
        let halfChunkSizeRoundedDown :Int = Int(floor((Double(chunkSize)/2.0)))
        
        // var chunkAverage = 0.0
        
        let valueCenter = image[centerX + centerY * width]
        
        var isBiggest = true
        // var isPeak = false
        
        //Checks if center pixel is the highest in the chunk. Also calculating average
        
        for checkingY in stride(from: centerY - halfChunkSizeRoundedDown, to: (centerY + halfChunkSizeRoundedDown), by: 1) {
            
            for checkingX in stride(from: centerX - halfChunkSizeRoundedDown, to: (centerX + halfChunkSizeRoundedDown), by: 1) {
                
                let valueChecking = image[checkingX + checkingY*width]
                
                if (checkingY != centerY || checkingX != centerX) { //Don't check against itself
                    if ( valueChecking >= valueCenter ) {
                        isBiggest = false;
                    }
                }
            }
        }
        
        return isBiggest
    }
}
