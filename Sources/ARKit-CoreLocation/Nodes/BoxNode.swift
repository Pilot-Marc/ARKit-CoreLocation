//
//  BoxNode.swift
//  ARCL
//
//  Created by Marc Alexander on 11/27/19.
//

import Foundation
import CoreLocation
import ARKit

public class BoxNode: LocationNode {

	public init(location: CLLocation, width: CLLocationDistance, height: CLLocationDistance, length: CLLocationDistance, color: UIColor) {
		print(#function)
		super.init(location: location)

		let geometry = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(length), chamferRadius: 0)
		geometry.firstMaterial?.diffuse.contents = color

		let shapeNode = SCNNode(geometry: geometry)					// Attach geometry to shape node
		shapeNode.name = ""
		shapeNode.removeFlicker()

//		shapeNode.eulerAngles.x = Float.pi / 4						// Pitch: rotation about the node’s x-axis
//		shapeNode.eulerAngles.y = Float.pi / 4						// Yaw:   rotation about the node’s y-axis
//		shapeNode.eulerAngles.z = Float.pi / 4						// Roll:  rotation about the node’s z-axis

		addChildNode(shapeNode)										// Attach shape node to ourself

	} // init(location:radius:color:)

	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		print(#function)

	} // deinit

} // BoxNode class
