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

	public init(location: CLLocation, image: UIImage) {
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

	} // init(location:radius:color:)

	// TODO: UIView -> UIImage convenience routine
	// TODO: CALyaer init method

	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		print(#function)

	} // deinit

	//**************************************************************************************************
	// Since Billboard nodes are flat, they have a unique scaling algorithm
	// TODO: Consolidate with other positioning & scaling methods
	//**************************************************************************************************
	override func updatePositionAndScale(setup: Bool = false, scenePosition: SCNVector3?,
										 locationNodeLocation nodeLocation: CLLocation,
										 locationManager: SceneLocationManager,
										 onCompletion: (() -> Void)) {

		guard let position = scenePosition, let location = locationManager.currentLocation else { return }
//		guard let annotationNode = annotationNode else { return }
		guard let annotationNode = childNodes.first as? AnnotationShape else { return }

		SCNTransaction.begin()
		SCNTransaction.animationDuration = setup ? 0.0 : 0.1

		let distance = self.location(locationManager.bestLocationEstimate).distance(from: location)

		childNodes.first?.renderingOrder = renderingOrder(fromDistance: distance)

		let adjustedDistance = self.adjustedDistance(setup: setup, position: position,
													 locationNodeLocation: nodeLocation, locationManager: locationManager)

		// The scale of a node with a billboard constraint applied is ignored
		// The annotation subnode itself, as a subnode, has the scale applied to it
		let appliedScale = self.scale
		self.scale = SCNVector3(x: 1, y: 1, z: 1)

		var scale: Float

		if scaleRelativeToDistance {
			scale = appliedScale.y
			annotationNode.scale = appliedScale
			annotationNode.childNodes.forEach { child in
				child.scale = appliedScale
			}
		} else {
			let scaleFunc = scalingScheme.getScheme()
			scale = scaleFunc(distance, adjustedDistance)

			annotationNode.scale = SCNVector3(x: scale, y: scale, z: scale)
			annotationNode.childNodes.forEach { node in
				node.scale = SCNVector3(x: scale, y: scale, z: scale)
			}
		}

		self.pivot = SCNMatrix4MakeTranslation(0, -1.1 * scale, 0)

		SCNTransaction.commit()

		onCompletion()

	} // updatePositionAndScale(setup:scenePosition:locationNodeLocation:locationManager;onCompletion:)

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
