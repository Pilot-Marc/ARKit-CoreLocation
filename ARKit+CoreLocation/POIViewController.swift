//
//  POIViewController.swift
//  ARKit+CoreLocation
//
//  Created by Andrew Hart on 02/07/2017.
//  Copyright © 2017 Project Dent. All rights reserved.
//

import ARCL
import ARKit
import MapKit
import SceneKit
import UIKit

@available(iOS 11.0, *)
/// Displays Points of Interest in ARCL
class POIViewController: UIViewController {
    @IBOutlet var mapView: MKMapView!
    @IBOutlet var infoLabel: UILabel!
    @IBOutlet weak var nodePositionLabel: UILabel!

    @IBOutlet var contentView: UIView!
	let sceneLocationView = SceneLocationView(trackingType: .orientationTracking)

    var userAnnotation: MKPointAnnotation?
    var locationEstimateAnnotation: MKPointAnnotation?

    var updateUserLocationTimer: Timer?
    var updateInfoLabelTimer: Timer?

    var centerMapOnUserLocation: Bool = true
    var routes: [MKRoute]?

    var showMap = false {
        didSet {
            guard let mapView = mapView else {
                return
            }
            mapView.isHidden = !showMap
        }
    }

    /// Whether to display some debugging data
    /// This currently displays the coordinate of the best location estimate
    /// The initial value is respected
    let displayDebugging = false

    let adjustNorthByTappingSidesOfScreen = false
    let addNodeByTappingScreen = false

    class func loadFromStoryboard() -> POIViewController {
        return UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "ARCLViewController") as! POIViewController
        // swiftlint:disable:previous force_cast
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // swiftlint:disable:next discarded_notification_center_observer
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
												self?.pauseAnimation()
        }
        // swiftlint:disable:next discarded_notification_center_observer
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                               object: nil,
                                               queue: nil) { [weak self] _ in
												self?.restartAnimation()
        }

		updateInfoLabelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
			self?.updateInfoLabel()
		}

        // Set to true to display an arrow which points north.
        // Checkout the comments in the property description and on the readme on this.
//        sceneLocationView.orientToTrueNorth = false
//        sceneLocationView.locationEstimateMethod = .coreLocationDataOnly

        sceneLocationView.showAxesNode = true
        sceneLocationView.showFeaturePoints = displayDebugging
        sceneLocationView.locationNodeTouchDelegate = self
//        sceneLocationView.delegate = self // Causes an assertionFailure - use the `arViewDelegate` instead:
        sceneLocationView.arViewDelegate = self
        sceneLocationView.locationNodeTouchDelegate = self

        // Now add the route or location annotations as appropriate
        addSceneModels()

        contentView.addSubview(sceneLocationView)
        sceneLocationView.frame = contentView.bounds

        mapView.isHidden = !showMap

        if showMap {
			updateUserLocationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
				self?.updateUserLocation()
			}

            routes?.forEach { mapView.addOverlay($0.polyline) }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        restartAnimation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        print(#function)
        pauseAnimation()
        super.viewWillDisappear(animated)
    }

    func pauseAnimation() {
        print("pause")
        sceneLocationView.pause()
    }

    func restartAnimation() {
        print("run")
        sceneLocationView.run()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sceneLocationView.frame = contentView.bounds
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first,
            let view = touch.view else { return }

        if mapView == view || mapView.recursiveSubviews().contains(view) {
            centerMapOnUserLocation = false
        } else {
            let location = touch.location(in: self.view)

            if location.x <= 40 && adjustNorthByTappingSidesOfScreen {
                print("left side of the screen")
                sceneLocationView.moveSceneHeadingAntiClockwise()
            } else if location.x >= view.frame.size.width - 40 && adjustNorthByTappingSidesOfScreen {
                print("right side of the screen")
                sceneLocationView.moveSceneHeadingClockwise()
            } else if addNodeByTappingScreen {
                let image = UIImage(named: "pin")!
                let annotationNode = LocationAnnotationNode(location: nil, image: image)
                annotationNode.scaleRelativeToDistance = false
                annotationNode.scalingScheme = .normal
                DispatchQueue.main.async {
                    // If we're using the touch delegate, adding a new node in the touch handler sometimes causes a freeze.
                    // So defer to next pass.
                    self.sceneLocationView.addLocationNodeForCurrentPosition(locationNode: annotationNode)
                }
            }
        }
    }
}

// MARK: - MKMapViewDelegate

@available(iOS 11.0, *)
extension POIViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.lineWidth = 3
        renderer.strokeColor = UIColor.blue.withAlphaComponent(0.5)

        return renderer
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation),
           let pointAnnotation = annotation as? MKPointAnnotation else { return nil }

        let marker = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)

        if pointAnnotation == self.userAnnotation {
            marker.displayPriority = .required
            marker.glyphImage = UIImage(named: "user")
        } else {
            marker.displayPriority = .required
            marker.markerTintColor = UIColor(hue: 0.267, saturation: 0.67, brightness: 0.77, alpha: 1.0)
            marker.glyphImage = UIImage(named: "compass")
        }

        return marker
    }
}

// MARK: - Implementation

@available(iOS 11.0, *)
extension POIViewController {

    /// Adds the appropriate ARKit models to the scene.  Note: that this won't
    /// do anything until the scene has a `currentLocation`.  It "polls" on that
    /// and when a location is finally discovered, the models are added.
    func addSceneModels() {
        // 1. Don't try to add the models to the scene until we have a current location
        guard sceneLocationView.sceneLocationManager.currentLocation != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.addSceneModels()
            }
            return
        }

        let box = SCNBox(width: 1, height: 0.2, length: 5, chamferRadius: 0.25)
        box.firstMaterial?.diffuse.contents = UIColor.gray.withAlphaComponent(0.5)

        // 2. If there is a route, show that
        if let routes = routes {
            sceneLocationView.addRoutes(routes: routes) { distance -> SCNBox in
                let box = SCNBox(width: 1.75, height: 0.5, length: distance, chamferRadius: 0.25)

//                // Option 1: An absolutely terrible box material set (that demonstrates what you can do):
//                box.materials = ["box0", "box1", "box2", "box3", "box4", "box5"].map {
//                    let material = SCNMaterial()
//                    material.diffuse.contents = UIImage(named: $0)
//                    return material
//                }

                // Option 2: Something more typical
                box.firstMaterial?.diffuse.contents = UIColor.blue.withAlphaComponent(0.7)
                return box
            }
        } else {
            // 3. If not, then show the fixed demo objects
            buildDemoData().forEach {
                sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: $0)
            }
            buildNewDemoData().forEach {
                sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: $0)
            }
        }

        // There are many different ways to add lighting to a scene, but even this mechanism (the absolute simplest)
        // keeps 3D objects fron looking flat
        sceneLocationView.autoenablesDefaultLighting = true

    }

    /// Builds the location annotations for a few random objects, scattered across the country
    ///
    /// - Returns: an array of annotation nodes.
    func buildDemoData() -> [LocationAnnotationNode] {
        var nodes: [LocationAnnotationNode] = []

        let spaceNeedle = buildNode(latitude: 47.6205, longitude: -122.3493, altitude: 225, imageName: "pin")
        nodes.append(spaceNeedle)

        let empireStateBuilding = buildNode(latitude: 40.7484, longitude: -73.9857, altitude: 14.3, imageName: "pin")
        nodes.append(empireStateBuilding)

        let canaryWharf = buildNode(latitude: 51.504607, longitude: -0.019592, altitude: 236, imageName: "pin")
        nodes.append(canaryWharf)

//      let applePark = buildViewNode(latitude: 37.334807, longitude: -122.009076, altitude: 100, text: "Apple Park")
//      nodes.append(applePark)

//      let theAlamo = buildViewNode(latitude: 29.4259671, longitude: -98.4861419, altitude: 300, text: "The Alamo")
//      nodes.append(theAlamo)

        return nodes
    }

    /// Builds the location annotations for a few random objects, scattered across the country
    ///
    /// - Returns: an array of location nodes.
    func buildNewDemoData() -> [LocationNode] {
		var nodes: [LocationNode] = []

		let currentCoordinates = sceneLocationView.sceneLocationManager.currentLocation!.coordinate

		// Static Text Marker: Apple Park

		let appleParkLoc = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.334807, longitude: -122.009076), altitude: 100)
		let appleParkMarker = staticMarker(text: "Apple Park")
		let appleParkNode = buildBillboardNode(location: appleParkLoc, view: appleParkMarker)
        nodes.append(appleParkNode)

		// Static Text Marker: The Alamo

		let theAlamaoLoc = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 29.4259671, longitude: -98.4861419), altitude: 300)
		let theAlamoMarker = staticMarker(text: "The Alamo")
		let theAlamoNode = buildBillboardNode(location: theAlamaoLoc, view: theAlamoMarker)
        nodes.append(theAlamoNode)

		// Dynamic Text Marker: Pike's Peak Time Stamp

		let pikesPeakLoc = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 38.8405322, longitude: -105.0442048), altitude: 4705)
		let pikesPeakMarker = dynamicMarker(text: "ABC")
		let pikesPeakNode = buildBillboardNode(location: pikesPeakLoc, layer: pikesPeakMarker)
        nodes.append(pikesPeakNode)

		// Image Marker: One

		let billboardOne2D = currentCoordinates.coordinateWithBearing(bearing: 280, distanceMeters: (300.0).nauticalMilesToMeters)
		let billboardOne3D = CLLocation(coordinate: billboardOne2D, altitude: 300)
		let billboardOneNode = buildBillboardNode(location: billboardOne3D, image: UIImage(named: "box4")!)
        nodes.append(billboardOneNode)

		// Image Marker: Two

		let billboardTwo2D = currentCoordinates.coordinateWithBearing(bearing: 300, distanceMeters: (3.0).nauticalMilesToMeters)
		let billboardTwo3D = CLLocation(coordinate: billboardTwo2D, altitude: 300)
		let billboardTwoNode = buildBillboardNode(location: billboardTwo3D, image: UIImage(named: "box5")!)
        nodes.append(billboardTwoNode)

		let greenCircle2D = currentCoordinates.coordinateWithBearing(bearing: 20, distanceMeters: (6.0).nauticalMilesToMeters)
		let greenCircle3D = CLLocation(coordinate: greenCircle2D, altitude: 300)
		let greenCircleNode = buildSphereNode(location: greenCircle3D, radius: (1.0).nauticalMilesToMeters, color: .green)
        nodes.append(greenCircleNode)

		// 3D Shape: Yellow Circle

		let yellowCircle2D = currentCoordinates.coordinateWithBearing(bearing: 350, distanceMeters: (6.0).nauticalMilesToMeters)
		let yellowCircle3D = CLLocation(coordinate: yellowCircle2D, altitude: 300)
		let yellowCircleNode = buildSphereNode(location: yellowCircle3D, radius: (1.0).nauticalMilesToMeters, color: .yellow)
        nodes.append(yellowCircleNode)

		// 3D Shape: Brown Cylinder

        let brownCylinder2D = currentCoordinates.coordinateWithBearing(bearing: 10, distanceMeters: (6.0).nauticalMilesToMeters)
        let brownCylinder3D = CLLocation(coordinate: brownCylinder2D, altitude: 300)
        let brownCylinderNode = buildCylinderNode(location: brownCylinder3D, radius: (1.0).nauticalMilesToMeters, height: (1.0).nauticalMilesToMeters, color: .brown)
        nodes.append(brownCylinderNode)

		// 3D Shape: Red Box

        let redBox2D = currentCoordinates.coordinateWithBearing(bearing: 30, distanceMeters: (5.0).nauticalMilesToMeters)
        let redBox3D = CLLocation(coordinate: redBox2D, altitude: 300)
        let redBoxNode = buildBoxNode(location: redBox3D, width: (1.0).nauticalMilesToMeters, height: (1.0).nauticalMilesToMeters, length: (1.0).nauticalMilesToMeters, color: .red)
        nodes.append(redBoxNode)

		// 3D Shape: Purple Text

        let purpleText2D = currentCoordinates.coordinateWithBearing(bearing: 40, distanceMeters: (5.0).nauticalMilesToMeters)
        let purpleText3D = CLLocation(coordinate: purpleText2D, altitude: 300)
        let purpleTextNode = buildTextNode(location: purpleText3D, string: "Hello World", size: 1000, color: .purple)
        nodes.append(purpleTextNode)

		// 3D Shape: Blob

		let cyanBlobCoords: [CLLocationCoordinate2D] = [
//			CLLocationCoordinate2D(latitude: 29.893, longitude: -97.863),		// hyi
//			CLLocationCoordinate2D(latitude: 30.195, longitude: -97.670),		// aus
//			CLLocationCoordinate2D(latitude: 30.397, longitude: -97.566),		// kedc
//			CLLocationCoordinate2D(latitude: 30.474, longitude: -98.121),		// 88r
			CLLocationCoordinate2D(latitude: 30.679, longitude: -97.679),		// gtu
//			CLLocationCoordinate2D(latitude: 30.518, longitude: -97.781),		// 40xs
			CLLocationCoordinate2D(latitude: 30.499, longitude: -97.969),		// kryw
			CLLocationCoordinate2D(latitude: 30.921, longitude: -97.541),		// 2tx
		]
        let cyanBlobNode = buildBlobNode(coords: cyanBlobCoords, floor: 300, height: (3.0).nauticalMilesToMeters, color: UIColor.cyan.withAlphaComponent(0.9))
        nodes.append(cyanBlobNode)

        return nodes
	} // buildNewDemoData() -? [LocationNode]

	// MARK: - Periodic Timer Callbacks

    @objc
    func updateUserLocation() {
        guard let currentLocation = sceneLocationView.sceneLocationManager.currentLocation else {
            return
        }

        DispatchQueue.main.async { [weak self ] in
            guard let self = self else {
                return
            }

            if self.userAnnotation == nil {
                self.userAnnotation = MKPointAnnotation()
                self.mapView.addAnnotation(self.userAnnotation!)
            }

            UIView.animate(withDuration: 0.5, delay: 0, options: .allowUserInteraction, animations: {
                self.userAnnotation?.coordinate = currentLocation.coordinate
            }, completion: nil)

            if self.centerMapOnUserLocation {
                UIView.animate(withDuration: 0.45,
                               delay: 0,
                               options: .allowUserInteraction,
                               animations: {
                                self.mapView.setCenter(self.userAnnotation!.coordinate, animated: false)
                }, completion: { _ in
                    self.mapView.region.span = MKCoordinateSpan(latitudeDelta: 0.0005, longitudeDelta: 0.0005)
                })
            }

            if self.displayDebugging {
                if let bestLocationEstimate = self.sceneLocationView.sceneLocationManager.bestLocationEstimate {
                    if self.locationEstimateAnnotation == nil {
                        self.locationEstimateAnnotation = MKPointAnnotation()
                        self.mapView.addAnnotation(self.locationEstimateAnnotation!)
                    }
                    self.locationEstimateAnnotation?.coordinate = bestLocationEstimate.location.coordinate
                } else if self.locationEstimateAnnotation != nil {
                    self.mapView.removeAnnotation(self.locationEstimateAnnotation!)
                    self.locationEstimateAnnotation = nil
                }
            }
        }
    }

    @objc
    func updateInfoLabel() {
        if let position = sceneLocationView.currentScenePosition {
            infoLabel.text = " x: \(position.x.short), y: \(position.y.short), z: \(position.z.short)\n"
        }

        if let eulerAngles = sceneLocationView.currentEulerAngles {
            infoLabel.text!.append(" Euler x: \(eulerAngles.x.short), y: \(eulerAngles.y.short), z: \(eulerAngles.z.short)\n")
        }

		if let eulerAngles = sceneLocationView.currentEulerAngles,
			let heading = sceneLocationView.sceneLocationManager.locationManager.heading,
			let headingAccuracy = sceneLocationView.sceneLocationManager.locationManager.headingAccuracy {
            let yDegrees = (((0 - eulerAngles.y.radiansToDegrees) + 360).truncatingRemainder(dividingBy: 360) ).short
			infoLabel.text!.append(" Heading: \(yDegrees)° • \(Float(heading).short)° • \(headingAccuracy)°\n")
		}

        let comp = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: Date())
        if let hour = comp.hour, let minute = comp.minute, let second = comp.second, let nanosecond = comp.nanosecond {
            let nodeCount = "\(sceneLocationView.sceneNode?.childNodes.count.description ?? "n/a") ARKit Nodes"
            infoLabel.text!.append(" \(hour.short):\(minute.short):\(second.short):\(nanosecond.short3) • \(nodeCount)")
        }
    }

	// MARK: - Old Node Builders

	func buildNode(latitude: CLLocationDegrees, longitude: CLLocationDegrees,
                   altitude: CLLocationDistance, imageName: String) -> LocationAnnotationNode {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let location = CLLocation(coordinate: coordinate, altitude: altitude)
        let image = UIImage(named: imageName)!
        return LocationAnnotationNode(location: location, image: image)
    }

    func buildViewNode(latitude: CLLocationDegrees, longitude: CLLocationDegrees,
                       altitude: CLLocationDistance, text: String) -> LocationAnnotationNode {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let location = CLLocation(coordinate: coordinate, altitude: altitude)
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        label.text = text
        label.backgroundColor = .green
        label.textAlignment = .center
        return LocationAnnotationNode(location: location, view: label)
    }

	// MARK: - New Node Builders

	func buildBillboardNode(location: CLLocation, image: UIImage) -> BillboardNode {
		return BillboardNode(location: location, image: image)
    }

	func buildBillboardNode(location: CLLocation, view: UIView) -> BillboardNode {
		return BillboardNode(location: location, view: view)
    }

	func buildBillboardNode(location: CLLocation, layer: CALayer) -> BillboardNode {
		return BillboardNode(location: location, layer: layer)
    }

    func buildSphereNode(location: CLLocation, radius: CLLocationDistance, color: UIColor) -> SphereNode {
        return SphereNode(location: location, radius: radius, color: color)
    }

    func buildCylinderNode(location: CLLocation, radius: CLLocationDistance, height: CLLocationDistance, color: UIColor) -> CylinderNode {
        return CylinderNode(location: location, radius: radius, height: height, color: color)
    }

    func buildBoxNode(location: CLLocation, width: CLLocationDistance, height: CLLocationDistance, length: CLLocationDistance, color: UIColor) -> BoxNode {
        return BoxNode(location: location, width: width, height: height, length: length, color: color)
    }

    func buildBlobNode(coords: [CLLocationCoordinate2D], floor: CLLocationDistance, height: CLLocationDistance, color: UIColor) -> BlobNode {
        return BlobNode(coords: coords, floor: floor, height: height, color: color)
    }

    func buildTextNode(location: CLLocation, string: String, size: CGFloat, color: UIColor) -> TextNode {
        return TextNode(location: location, string: string, size: size, color: color)
    }

	// MARK: - Marker Builders

	func staticMarker (text: String) -> UIView {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        label.text = text
        label.textAlignment = .center
		label.textColor = .white
		label.backgroundColor = UIColor(red: 0.6, green: 0, blue: 0, alpha: 1)
		label.layer.masksToBounds = true
		label.layer.cornerRadius = 10

		return label
	} // staticMarker(text:)

	func dynamicMarker (text: String) -> CALayer {
		let layer = CATextLayer()
		layer.alignmentMode = .center
		layer.fontSize = 14
		layer.cornerRadius = 4
		layer.foregroundColor = UIColor.black.cgColor
 		layer.backgroundColor = UIColor.white.cgColor
		layer.frame = CGRect(x: 0, y: 0, width: 180, height: 36)
		_ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
 			layer.string = "The current time is:\n" + Date().description
 		}
		return layer
	} // dynamicMarker

}

// MARK: - LNTouchDelegate
@available(iOS 11.0, *)
extension POIViewController: LNTouchDelegate {

    func annotationNodeTouched(node: AnnotationNode) {
		if let node = node.parent as? LocationNode {
			let coords = "\(node.location.coordinate.latitude.short)° \(node.location.coordinate.longitude.short)°"
			let altitude = "\(node.location.altitude.short)m"
			let tag = node.tag ?? ""
			nodePositionLabel.text = " Annotation node at \(coords), \(altitude) - \(tag)"
		}
    }

    func locationNodeTouched(node: LocationNode) {
        print("Location node touched - tag: \(node.tag ?? "")")
		let coords = "\(node.location.coordinate.latitude.short)° \(node.location.coordinate.longitude.short)°"
		let altitude = "\(node.location.altitude.short)m"
		let tag = node.tag ?? ""
		nodePositionLabel.text = " Location node at \(coords), \(altitude) - \(tag)"
    }

}

// MARK: - Helpers

extension DispatchQueue {
    func asyncAfter(timeInterval: TimeInterval, execute: @escaping () -> Void) {
        self.asyncAfter(
            deadline: DispatchTime.now() + Double(Int64(timeInterval * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC),
            execute: execute)
    }
}

extension UIView {
    func recursiveSubviews() -> [UIView] {
        var recursiveSubviews = self.subviews

        subviews.forEach { recursiveSubviews.append(contentsOf: $0.recursiveSubviews()) }

        return recursiveSubviews
    }
}
