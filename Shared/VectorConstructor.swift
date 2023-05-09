//
//  VectorConstructor.swift
//  FITSDocument
//
//  Created by Jakob Lockard on 4/7/22.
//

import Foundation
import SwiftUI
import simd
import UniformTypeIdentifiers
import FITS
import FITSKit
import Accelerate

class VectorConstructor :NSObject {
    
    func findMaxVectorDXDY(maximumVector:(primary:(point1: simd_float3, point2: simd_float3), alignment: ((point1: simd_float3, point2: simd_float3))))->(deltaX: Float, deltaY: Float){
        
        
        if(maximumVector.primary == maximumVector.alignment){
            
            return (deltaX: Float(0.0), deltaY: Float(0.0))
        }
        
        
        
        
        //            let deltaX = maximumVector.primary.point1.x * cos(angle) - maximumVector.primary.point1.y * sin(angle) - maximumVector.alignment.point1.x
        //
        //            let deltaY = maximumVector.primary.point1.x * sin(angle) + maximumVector.primary.point1.y * cos(angle) - maximumVector.alignment.point1.y
        
        let oldX = maximumVector.alignment.point1.x
        let oldY = maximumVector.alignment.point1.y
        
        let deltaX1 = maximumVector.alignment.point1.x  - maximumVector.primary.point1.x
        
        let deltaY1 = maximumVector.alignment.point1.y - maximumVector.primary.point1.y
        
        let deltaX2 = maximumVector.alignment.point2.x - maximumVector.primary.point2.x
        
        let deltaY2 = maximumVector.alignment.point2.y - maximumVector.primary.point2.y
        
        //print("Angle", angle, "DeltaX", deltaX, "DeltaY", deltaY)
        
        let deltaX = (deltaX2+deltaX1)/2.0
        let deltaY = (deltaY2+deltaY1)/2.0
        
        return((deltaX: -deltaX, deltaY: -deltaY) )
        //        return((angle: Float(0.000), deltaX: goodDeltaXArray.max()!, goodDeltaYArray.max()!) )
        
    }
    
    func findLongestVector(matchedPointsArray: [(primary: simd_float3,  alignment: simd_float3)]) -> (primary:(point1: simd_float3, point2: simd_float3), alignment: ((point1: simd_float3, point2: simd_float3))){
        
        var maximumLength :Float  = -100000.0
        var maximumVector :[(primary:(point1: simd_float3, point2: simd_float3), alignment: ((point1: simd_float3, point2: simd_float3)))] = []
        
        for firstPoint in stride(from: 0, to: matchedPointsArray.count - 2, by: 1){
            
            //var maxLength :Float = -10000.0
            var firstPrimaryPoint = matchedPointsArray[firstPoint].primary
            var firstAlignmentPoint = matchedPointsArray[firstPoint].alignment
            var secondPrimaryPoint = matchedPointsArray[firstPoint].primary
            var secondAlignmentPoint = matchedPointsArray[firstPoint].alignment
            
            for secondPoint in stride(from: firstPoint, to: matchedPointsArray.count - 1, by: 1){
                
                let length = simd_distance(matchedPointsArray[firstPoint].primary, matchedPointsArray[secondPoint].primary)
                
                if (length > maximumLength ){
                    
                    secondAlignmentPoint = matchedPointsArray[secondPoint].alignment
                    secondPrimaryPoint = matchedPointsArray[secondPoint].primary
                    
                    
                }
                
                
                
            }
            maximumVector.append((primary:(point1: firstPrimaryPoint, point2: secondPrimaryPoint), alignment: ((point1: firstAlignmentPoint, point2: secondAlignmentPoint))))
            
        }
        
        return maximumVector[0]
        
    }
    
    func findMaxVectorAngle(maximumVector:(primary:(point1: simd_float3, point2: simd_float3), alignment: ((point1: simd_float3, point2: simd_float3))))->(Float){
        
        
        if(maximumVector.primary == maximumVector.alignment){
            
            return (Float(0.0))
        }
        
        
        
        
        //let primaryVector = primaryVectorArray[1] - primaryVectorArray[0]
        
        let primaryVector = maximumVector.primary.point2 - maximumVector.primary.point1
        
        print("lengthofPrimary", simd_length(primaryVector))
        
        
        //let alignmentVector = alignmentVectorArray[1] - alignmentVectorArray[0]
        
        let alignmentVector = maximumVector.alignment.point2 - maximumVector.alignment.point1
        
        print("lengthofAlignment", simd_length(alignmentVector))
        
        var dotProduct = simd_dot(simd_precise_normalize(primaryVector), simd_precise_normalize(alignmentVector))
        
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
        
        
        return( angle )
        //        return((angle: Float(0.000), deltaX: goodDeltaXArray.max()!, goodDeltaYArray.max()!) )
        
    }

}
