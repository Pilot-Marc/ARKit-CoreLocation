//
//  BillboardNode.swift
//  ARCL
//
//  Created by Marc Alexander on 11/27/19.
//

import Foundation
import CoreLocation
import ARKit

public class BillboardNode: LocationNode {

	public init(location: CLLocation?, image: UIImage) {
		print(#function)
		super.init(location: location)

		let geometry = SCNPlane(width: image.size.width / 100, height: image.size.height / 100)		// The node's geometry
		geometry.firstMaterial!.diffuse.contents = image
		geometry.firstMaterial!.lightingModel = .constant

		let shapeNode = AnnotationShape(name: "", view: nil, image: image)							// Attach geometry to shape node
		shapeNode.geometry = geometry
		shapeNode.name = ""
		shapeNode.removeFlicker()

		let billboardConstraint			= SCNBillboardConstraint()									// Special config because we're a 2D node
		billboardConstraint.freeAxes 	= SCNBillboardAxis.Y
		constraints 					= [billboardConstraint]

//		shapeNode.eulerAngles.x = Float.pi / 4						// Pitch: rotation about the node’s x-axis
//		shapeNode.eulerAngles.y = Float.pi / 4						// Yaw:   rotation about the node’s y-axis
//		shapeNode.eulerAngles.z = Float.pi / 4						// Roll:  rotation about the node’s z-axis

		addChildNode(shapeNode)										// Attach shape node to ourself

	} // init(location:image:)

	public init(location: CLLocation?, layer: CALayer) {
		print(#function)
		super.init(location: location)

		let geometry = SCNPlane(width: layer.bounds.size.width / 100, height: layer.bounds.size.height / 100)	// The node's geometry
		geometry.firstMaterial!.diffuse.contents = layer
		geometry.firstMaterial!.lightingModel = .constant

		let shapeNode = AnnotationShape(name: "", view: nil, image: nil, layer: layer)				// Attach geometry to shape node
		shapeNode.geometry = geometry
		shapeNode.name = ""
		shapeNode.removeFlicker()

		let billboardConstraint			= SCNBillboardConstraint()									// Special config because we're a 2D node
		billboardConstraint.freeAxes 	= SCNBillboardAxis.Y
		constraints 					= [billboardConstraint]

//		shapeNode.eulerAngles.x = Float.pi / 4						// Pitch: rotation about the node’s x-axis
//		shapeNode.eulerAngles.y = Float.pi / 4						// Yaw:   rotation about the node’s y-axis
//		shapeNode.eulerAngles.z = Float.pi / 4						// Roll:  rotation about the node’s z-axis

		addChildNode(shapeNode)										// Attach shape node to ourself

	} // init(location:layer:)

	//**************************************************************************************************
	// Convenience routine (converts UIView -> UIImage)
	// TODO: Clean this up when we drop iOS 9 support 
	//**************************************************************************************************
	public convenience init(location: CLLocation?, view: UIView) {
		if #available(iOS 10.0, *) {
			self.init(location: location, image: view.image)
		} else {
			self.init(location: location, image: UIImage())
		}
	}

	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		print(#function)

	} // deinit

} // BillboardNode class

//**************************************************************************************************
// Shape used for a Billbaord Node
// Was originally called Annotation Node
//**************************************************************************************************
open class AnnotationShape: SCNNode {

	public var view: UIView?
	public var image: UIImage?
	public var layer: CALayer?

	//**************************************************************************************************
	public init(name: String, view: UIView?, image: UIImage?, layer: CALayer? = nil) {
		super.init()

		self.name = name
		self.view = view
		self.image = image
		self.layer = layer

	} // init(name:view:image:layer:)

	//**************************************************************************************************
	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

} // AnnotationShape class
