//
//  CalculatePlotData.swift
//  CalculatePlotData
//
//  Created by Jeff_Terry on 12/6/21.
//

import Foundation
import SwiftUI
import CorePlot

class CalculatePlotData: ObservableObject {
    
    var plotDataModel: PlotDataClass? = nil
    

    func plotYEqualsX()
    {
        
        //set the Plot Parameters
        plotDataModel!.changingPlotParameters.yMax = 10.0
        plotDataModel!.changingPlotParameters.yMin = -5.0
        plotDataModel!.changingPlotParameters.xMax = 10.0
        plotDataModel!.changingPlotParameters.xMin = -5.0
        plotDataModel!.changingPlotParameters.xLabel = "x"
        plotDataModel!.changingPlotParameters.yLabel = "y"
        plotDataModel!.changingPlotParameters.lineColor = .red()
        plotDataModel!.changingPlotParameters.title = " y = x"
        
        plotDataModel!.zeroData()
        var plotData :[plotDataType] =  []
        
        
        for i in 0 ..< 120 {

            //create x values here

            let x = -2.0 + Double(i) * 0.2

        //create y values here

        let y = x


            let dataPoint: plotDataType = [.X: x, .Y: y]
            plotData.append(contentsOf: [dataPoint])
        
        }
        
        plotDataModel!.appendData(dataPoint: plotData)
        
        
    }
    
    
    func ploteToTheMinusX()
    {
        
        //set the Plot Parameters
        plotDataModel!.changingPlotParameters.yMax = 10
        plotDataModel!.changingPlotParameters.yMin = -3.0
        plotDataModel!.changingPlotParameters.xMax = 10.0
        plotDataModel!.changingPlotParameters.xMin = -3.0
        plotDataModel!.changingPlotParameters.xLabel = "x"
        plotDataModel!.changingPlotParameters.yLabel = "y = exp(-x)"
        plotDataModel!.changingPlotParameters.lineColor = .blue()
        plotDataModel!.changingPlotParameters.title = "exp(-x)"

        plotDataModel!.zeroData()
        var plotData :[plotDataType] =  []
        for i in 0 ..< 60 {

            //create x values here

            let x = -2.0 + Double(i) * 0.2

        //create y values here

        let y = exp(-x)
            
            let dataPoint: plotDataType = [.X: x, .Y: y]
            plotData.append(contentsOf: [dataPoint])
        }
        
        plotDataModel!.appendData(dataPoint: plotData)
        
        return
    }
    
    func plotHistogram(histogram:[UInt])
    {
        
        //set the Plot Parameters
        plotDataModel!.changingPlotParameters.yMax = (1.5/100)*Double(histogram.max()!)
        //plotDataModel!.changingPlotParameters.yMax = Double(histogram.max()!)
        plotDataModel!.changingPlotParameters.yMin = Double(histogram.min()!)-2000.0
        plotDataModel!.changingPlotParameters.xMax = Double(1100)//come back to this (original = 1100)
        plotDataModel!.changingPlotParameters.xMin = -100.0
        plotDataModel!.changingPlotParameters.xLabel = "Bin"
        plotDataModel!.changingPlotParameters.yLabel = "Appearances"
        plotDataModel!.changingPlotParameters.lineColor = .red()
        plotDataModel!.changingPlotParameters.title = "Histogram"

        plotDataModel!.zeroData()
        var plotData :[plotDataType] =  []
        for item in histogram{

            let y = Double(item)/100
            let dataPoint: plotDataType = [.X: plotDataModel!.pointNumber, .Y: y]
            plotData.append(contentsOf: [dataPoint])
            
            plotDataModel?.pointNumber += 1
        }
        
        plotDataModel!.appendData(dataPoint: plotData)
        
        return
    }
    
}
