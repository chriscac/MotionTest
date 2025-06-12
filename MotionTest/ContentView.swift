//
//  ContentView.swift
//  MotionTest
//
//  Created by Chris Cacioppe on 6/10/25.
//

import SwiftUI
import CoreMotion
import Combine

public struct Grid: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Major grid lines (darker, less frequent)
        let majorDivisions = 4
        
        // Vertical major lines
        for i in 0...majorDivisions {
            let x = rect.width * CGFloat(i) / CGFloat(majorDivisions)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        // Horizontal major lines
        for i in 0...majorDivisions {
            let y = rect.height * CGFloat(i) / CGFloat(majorDivisions)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        // Minor grid lines (lighter, more frequent)
        let minorDivisions = 16
        
        // Vertical minor lines
        for i in 0...minorDivisions {
            // Skip if this would be a major line
            if i % (minorDivisions / majorDivisions) != 0 {
                let x = rect.width * CGFloat(i) / CGFloat(minorDivisions)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: rect.height))
            }
        }
        
        // Horizontal minor lines
        for i in 0...minorDivisions {
            // Skip if this would be a major line
            if i % (minorDivisions / majorDivisions) != 0 {
                let y = rect.height * CGFloat(i) / CGFloat(minorDivisions)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: rect.width, y: y))
            }
        }
        
        return path
    }
}

class MotionManager: ObservableObject {
    private var motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()
    @Published var x: Double = 0.0
    @Published var y: Double = 0.0

    init() {
        motionQueue.maxConcurrentOperationCount = 1
        motionQueue.qualityOfService = .userInteractive
        startUpdates()
    }
    
    private func startUpdates() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 1.0 / 30.0 // Reduced from 60fps to 30fps
        motionManager.startAccelerometerUpdates(to: motionQueue) { [weak self] data, _ in
            guard let data = data else { return }
            
            // Only update if the change is significant enough to avoid excessive updates
            let newX = data.acceleration.x
            let newY = data.acceleration.y
            
            DispatchQueue.main.async {
                self?.x = newX
                self?.y = newY
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    
    // State variables for customization
    @State private var showCustomizationSheet = false
    
    // Background color (customizable)
    @State private var backgroundColor = Color(red: 0.13, green: 0.13, blue: 0.15)
    
    // Colors
    @State private var primaryColor = Color(red: 0.97, green: 0.42, blue: 0.39)
    
    // Shadow customization by opacity and blur radius (colors derived from primaryColor and black)
    @State private var ambientShadowOpacity: Double = 0.3
    @State private var ambientShadowBlurRadius: CGFloat = 5.0
    @State private var primaryShadowOpacity: Double = 0.2
    @State private var primaryShadowBlurRadius: CGFloat = 3.5
    
    // Overlay customization (border color, opacity, blur)
    @State private var overlayBorderColor = Color.black.opacity(0.9)
    @State private var overlayBorderOpacity: Double = 0.25
    @State private var overlayBlurRadius: CGFloat = 0.0
    
    // Lighting and opacity (lightingIntensity removed, replaced with fixed value in gradient calculations)
    @State private var startOpacity: Double = 0.6
    @State private var endOpacity: Double = 0.0
    @State private var specularBlurRadius: CGFloat = 0.0
    
    // Debug overlay toggle
    @State private var showDebugOverlay = true
    
    // Motion toggle options
    @State private var enableLightingMotion = true  // Controls whether lighting effects respond to motion
    @State private var enableShapeMotion = true     // Controls whether shape rotation responds to motion
    
    // New motion responsiveness factor
    @State private var motionResponsiveness: Double = 1.0
    
    // New invert rotation direction toggle (on by default)
    @State private var invertRotationDirection = true
    
    // For the segmented control in the customization sheet
    enum CustomizationTab: String, CaseIterable, Hashable {
        case motion = "Motion"
        case appearance = "Colors & Lighting"
        case debug = "Debug"
    }
    @State private var selectedTab: CustomizationTab = .motion
    
    // Computed properties for rotation values using motionResponsiveness and invertRotationDirection
    private var x: Double { motionManager.x * motionResponsiveness }
    private var y: Double { motionManager.y * motionResponsiveness }
    private var xRotationDegrees: Double { (invertRotationDirection ? -y : y) * rotationIntensity }
    private var yRotationDegrees: Double { (invertRotationDirection ? x : -x) * rotationIntensity }
    
    @State private var rotationIntensity: Double = 20.0
    
    // Compute shadow colors from opacities and colors
    private var ambientShadowColor: Color {
        primaryColor.opacity(ambientShadowOpacity)
    }
    private var primaryShadowColor: Color {
        Color.black.opacity(primaryShadowOpacity)
    }
    
    // Lighting intensity is now a fixed constant for gradient calculations
    private let fixedLightingIntensity: Double = 0.5
    
    // Calculate gradient points based on device motion to simulate specular lighting
    private func calculateGradientStartPoint(x: Double, y: Double) -> UnitPoint {
        // Normalize values to 0-1 range with 0.5 as the center point
        // Invert X for natural light direction (rolling left moves highlight right)
        // Note: x and y are raw values here, need to apply motionResponsiveness explicitly
        let normalizedX = 0.5 + max(min(x * motionResponsiveness * fixedLightingIntensity, 0.5), -0.5)
        let normalizedY = 0.5 - max(min(y * motionResponsiveness * fixedLightingIntensity, 0.5), -0.5)
        return UnitPoint(x: normalizedX, y: normalizedY)
    }
    
    private func calculateGradientEndPoint(x: Double, y: Double) -> UnitPoint {
        // End point should be opposite to start point for realistic light reflection
        let startPoint = calculateGradientStartPoint(x: x, y: y)
        return UnitPoint(x: 1 - startPoint.x, y: 1 - startPoint.y)
    }
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                
                
                // Motion Preview Stack
                ZStack {
                    // Grid rendered as the bottommost layer when debug overlay is enabled
                    if showDebugOverlay {
                        Grid()
                            .stroke(.secondary.opacity(0.2), lineWidth: 0.5)
                            .frame(width: geo.size.width * 0.6, height: geo.size.width * 0.6)
                    }
                    
                    // Apply shadow offsets with motion responsiveness and respect inversion setting
                    // Only invert the X (roll) direction, not the Y (pitch) direction
                    // x and y already include motionResponsiveness from the computed properties
                    let shadowX = enableLightingMotion ? (invertRotationDirection ? x : -x) * fixedLightingIntensity * 15 : 0
                    let shadowY = enableLightingMotion ? -y * fixedLightingIntensity * 15 : 0
                    let frameWidth: CGFloat = 100
                    let frameHeight: CGFloat = 75


                    Group{
                        
                        RoundedRectangle(cornerRadius: 100, style: .continuous)
                            .fill(primaryColor) // Customizable: Primary fill color
                            .frame(width: frameWidth, height: frameHeight)
                        
                    

                    RoundedRectangle(cornerRadius: 100, style: .continuous)
                        .fill(primaryColor) // Customizable: Primary fill color
                        .frame(width: frameWidth, height: frameHeight)
                        // Customizable: Color and blur radius for ambient shadow
                        .shadow(
                            color: ambientShadowColor,
                            radius: ambientShadowBlurRadius,
                            x: shadowX,
                            y: shadowY
                        )
                        // Customizable: Color and blur radius for primary shadow
                        .shadow(
                            color: primaryShadowColor,
                            radius: primaryShadowBlurRadius,
                            x: shadowX,
                            y: shadowY
                        )
                        .overlay(
                            ZStack{
                                
                                // Lighting Effects
                                
                                // Customizable: Color, opacity, and blur for overlay border
                                Capsule()
                                    .fill(.clear)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [overlayBorderColor.opacity(0), overlayBorderColor]),
                                            startPoint: calculateGradientStartPoint(x: enableLightingMotion ? -x : 0, y: enableLightingMotion ? -y : 0),
                                            endPoint: calculateGradientEndPoint(x: enableLightingMotion ? -x : 0, y: enableLightingMotion ? -y : 0)
                                        ),
                                                  lineWidth: 1
                                    )
                                    .opacity(overlayBorderOpacity)
                                    .blendMode(.darken)
                                    .blur(radius: overlayBlurRadius)


                                // Lighting specular
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.white.opacity(startOpacity), Color.white.opacity(0)]),
                                            startPoint: calculateGradientStartPoint(x: enableLightingMotion ? -x : 0, y: enableLightingMotion ? -y : 0),
                                            endPoint: calculateGradientEndPoint(x: enableLightingMotion ? -x : 0, y: enableLightingMotion ? -y : 0)
                                        ),
                                        lineWidth: 1
                                    )
                                    .opacity(0.45) // Customizable: Specular highlight opacity
                                    .blendMode(.plusLighter)
                                    .blur(radius: specularBlurRadius) // Specular highlight blur
                            }
                                .clipShape(Capsule())
                        )
                        
                        
                    }
                    .rotation3DEffect(
                        .degrees(enableShapeMotion ? (invertRotationDirection ? -y : y) * rotationIntensity : 0),
                        axis: (x: 1, y: 0, z: 0)
                    )
                    .rotation3DEffect(
                        .degrees(enableShapeMotion ? (invertRotationDirection ? x : -x) * rotationIntensity : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    
                    // Debug overlay
                    if showDebugOverlay {
                        MotionDebugOverlay(
                            x: x,
                            y: y,
                            rotationIntensity: rotationIntensity
                        )
                    }
                   
                
                }
                .frame(maxHeight: showCustomizationSheet ? geo.size.height / 2 : .infinity)
                .animation(.easeInOut(duration: 0.36), value: showCustomizationSheet)
                
                Spacer()
                
                VStack(spacing: 20) {
                    
                    // Button to open customization sheet
                    Button(action: {
                        showCustomizationSheet = true
                    }) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("Customize")
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(
                            Capsule()
                                .fill(.ultraThickMaterial)
                        )
                    }
                    .foregroundStyle(.primary)
                    .padding(.top, 20)

                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $showCustomizationSheet) {
                NavigationView {
                    VStack(spacing: 0) {
                        // Segmented control for tabs
                        Picker("Customization Options", selection: $selectedTab) {
                            ForEach(CustomizationTab.allCases, id: \.self) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .padding(.top)
                        
                        Divider()
                            .padding(.vertical, 10)
                        
                        // Content based on selected tab
                        ScrollView {
                            VStack(spacing: 20) {
                                switch selectedTab {
                                case .motion:
                                    MotionParametersView(
                                        rotationIntensity: Binding(
                                            get: { rotationIntensity },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    rotationIntensity = newValue
                                                }
                                            }
                                        ),
                                        enableLightingMotion: Binding(
                                            get: { enableLightingMotion },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    enableLightingMotion = newValue
                                                }
                                            }
                                        ),
                                        enableShapeMotion: Binding(
                                            get: { enableShapeMotion },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    enableShapeMotion = newValue
                                                }
                                            }
                                        ),
                                        motionResponsiveness: Binding(
                                            get: { motionResponsiveness },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    motionResponsiveness = newValue
                                                }
                                            }
                                        ),
                                        invertRotationDirection: Binding(
                                            get: { invertRotationDirection },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    invertRotationDirection = newValue
                                                }
                                            }
                                        )
                                    )
                                case .appearance:
                                    ColorsAndLightingView(
                                        backgroundColor: Binding(
                                            get: { backgroundColor },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    backgroundColor = newValue
                                                }
                                            }
                                        ),
                                        primaryColor: Binding(
                                            get: { primaryColor },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    primaryColor = newValue
                                                }
                                            }
                                        ),
                                        startOpacity: Binding(
                                            get: { startOpacity },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    startOpacity = newValue
                                                }
                                            }
                                        ),
                                        endOpacity: Binding(
                                            get: { endOpacity },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    endOpacity = newValue
                                                }
                                            }
                                        ),
                                        ambientShadowOpacity: Binding(
                                            get: { ambientShadowOpacity },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    ambientShadowOpacity = newValue
                                                }
                                            }
                                        ),
                                        ambientShadowBlurRadius: Binding(
                                            get: { ambientShadowBlurRadius },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    ambientShadowBlurRadius = newValue
                                                }
                                            }
                                        ),
                                        primaryShadowOpacity: Binding(
                                            get: { primaryShadowOpacity },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    primaryShadowOpacity = newValue
                                                }
                                            }
                                        ),
                                        primaryShadowBlurRadius: Binding(
                                            get: { primaryShadowBlurRadius },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    primaryShadowBlurRadius = newValue
                                                }
                                            }
                                        ),
                                        overlayBorderColor: Binding(
                                            get: { overlayBorderColor },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    overlayBorderColor = newValue
                                                }
                                            }
                                        ),
                                        overlayBorderOpacity: Binding(
                                            get: { overlayBorderOpacity },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    overlayBorderOpacity = newValue
                                                }
                                            }
                                        ),
                                        overlayBlurRadius: Binding(
                                            get: { overlayBlurRadius },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    overlayBlurRadius = newValue
                                                }
                                            }
                                        ),
                                        specularBlurRadius: Binding(
                                            get: { specularBlurRadius },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    specularBlurRadius = newValue
                                                }
                                            }
                                        )
                                    )
                                case .debug:
                                    DebugView(
                                        x: x,
                                        y: y,
                                        xRotationDegrees: xRotationDegrees,
                                        yRotationDegrees: yRotationDegrees,
                                        showDebugOverlay: Binding(
                                            get: { showDebugOverlay },
                                            set: { newValue in
                                                DispatchQueue.main.async {
                                                    showDebugOverlay = newValue
                                                }
                                            }
                                        )
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                    .navigationTitle("Customize Effects")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showCustomizationSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.fraction(0.5)])
            }
        }
        .background(.black.opacity(0.15)) // Customizable: Background overlay color
        .background(backgroundColor) // Customizable: Background fill color

    }
    
    // MARK: - Tab Views
    
    // Motion Parameters View
    struct MotionParametersView: View {
        @Binding var rotationIntensity: Double
        @Binding var enableLightingMotion: Bool
        @Binding var enableShapeMotion: Bool
        @Binding var motionResponsiveness: Double
        
        @Binding var invertRotationDirection: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("Motion Effects")
                    .font(.headline)
                
                SliderRow(title: "Motion Responsiveness", value: $motionResponsiveness, range: 0...1)
                Text("Lower values dampen or disable all motion-driven effects.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Rotation intensity slider
                SliderRow(
                    title: "Rotation Intensity",
                    value: Binding(
                        get: { rotationIntensity },
                        set: { newValue in
                            DispatchQueue.main.async {
                                rotationIntensity = newValue
                            }
                        }
                    ),
                    range: 0...40
                )
                
                Toggle("Lighting Responds to Motion", isOn: Binding(
                    get: { enableLightingMotion },
                    set: { newValue in
                        DispatchQueue.main.async {
                            enableLightingMotion = newValue
                        }
                    }
                ))
                Toggle("Shape Responds to Motion", isOn: Binding(
                    get: { enableShapeMotion },
                    set: { newValue in
                        DispatchQueue.main.async {
                            enableShapeMotion = newValue
                        }
                    }
                ))
                
                Toggle("Invert Rotation Direction", isOn: $invertRotationDirection)
                
                Text("Use these toggles to control whether lighting and shape rotation respond to device motion.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
            }
        }
    }
    
    // Colors and Lighting View
    struct ColorsAndLightingView: View {
        @Binding var backgroundColor: Color
        @Binding var primaryColor: Color
        @Binding var startOpacity: Double
        @Binding var endOpacity: Double
        
        @Binding var ambientShadowOpacity: Double
        @Binding var ambientShadowBlurRadius: CGFloat
        @Binding var primaryShadowOpacity: Double
        @Binding var primaryShadowBlurRadius: CGFloat
        @Binding var overlayBorderColor: Color
        @Binding var overlayBorderOpacity: Double
        @Binding var overlayBlurRadius: CGFloat
        @Binding var specularBlurRadius: CGFloat
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Background")
                        .font(.headline)
                    
                    ColorPickerRow(title: "Background Color", color: $backgroundColor)
                }
                
                Divider()
                    .padding(.vertical, 5)
                
                Group {
                    Text("Fill Color")
                        .font(.headline)
                    
                    ColorPickerRow(title: "Primary Color", color: $primaryColor)
                }
                
                Divider()
                    .padding(.vertical, 5)
                
                Group {
                    Text("Shadows")
                        .font(.headline)
                    
                    Text("Ambient Shadow")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    SliderRow(title: "Opacity", value: $ambientShadowOpacity, range: 0...1)
                    SliderRow(title: "Blur Radius", value: Binding<Double>(
                        get: { Double(ambientShadowBlurRadius) },
                        set: { ambientShadowBlurRadius = CGFloat($0) }
                    ), range: 0...20)
                    
                    Text("Primary Shadow")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    
                    SliderRow(title: "Opacity", value: $primaryShadowOpacity, range: 0...1)
                    SliderRow(title: "Blur Radius", value: Binding<Double>(
                        get: { Double(primaryShadowBlurRadius) },
                        set: { primaryShadowBlurRadius = CGFloat($0) }
                    ), range: 0...20)
                }
                
                Divider()
                    .padding(.vertical, 5)
                
                Group {
                    Text("Border Shadow")
                        .font(.headline)
                    
                    ColorPickerRow(title: "Border Color", color: $overlayBorderColor)
                    SliderRow(title: "Border Opacity", value: $overlayBorderOpacity, range: 0...1)
                    SliderRow(title: "Border Blur Radius", value: Binding<Double>(
                        get: { Double(overlayBlurRadius) },
                        set: { overlayBlurRadius = CGFloat($0) }
                    ), range: 0...10)
                }
                
                Divider()
                    .padding(.vertical, 5)
                
                Group {
                    Text("Specular Highlight")
                        .font(.headline)
                    
                    SliderRow(title: "Highlight Intensity", value: $startOpacity, range: 0...1)
                    SliderRow(title: "Highlight Blur", value: Binding<Double>(
                        get: { Double(specularBlurRadius) },
                        set: { specularBlurRadius = CGFloat($0) }
                    ), range: 0...10)
                    
                    Text("These settings control how the lighting appears to move with device motion.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }
            }
        }
    }
    
    // Debug View
    struct DebugView: View {
        let x: Double
        let y: Double
        let xRotationDegrees: Double
        let yRotationDegrees: Double
        @Binding var showDebugOverlay: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("Motion Data")
                    .font(.headline)
                
                // Values display
                HStack(spacing: 20) {
                    ValueDisplay(title: "X", value: x)
                    ValueDisplay(title: "Y", value: y)
                }
                
                // Rotation display
                HStack(spacing: 20) {
                    ValueDisplay(title: "X Rotation", value: xRotationDegrees, suffix: "°")
                    ValueDisplay(title: "Y Rotation", value: yRotationDegrees, suffix: "°")
                }
                
                Divider()
                    .padding(.vertical, 5)
                
                // Debug settings
                Toggle("Show Debug Overlay", isOn: Binding(
                    get: { showDebugOverlay },
                    set: { newValue in
                        DispatchQueue.main.async {
                            showDebugOverlay = newValue
                        }
                    }
                ))
                
                if showDebugOverlay {
                    Text("The debug overlay visualizes motion data and shows how device rotation affects the interface.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// Helper view for displaying values
struct ValueDisplay: View {
    let title: String
    let value: Double
    var suffix: String = ""
    
    var body: some View {
        HStack() {
            Text(title)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(String(format: "%.2f", value) + suffix)

        }
        .font(.system(.caption, design: .monospaced))

    }
}

// Helper views for the customization panel
struct ColorPickerRow: View {
    let title: String
    @Binding var color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .frame(width: 140, alignment: .leading)
            Spacer()
            ColorPicker("", selection: Binding(
                get: { color },
                set: { newValue in
                    DispatchQueue.main.async {
                        color = newValue
                    }
                }
            ))
                .labelsHidden()
        }
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            Slider(value: Binding(
                get: { value },
                set: { newValue in
                    DispatchQueue.main.async {
                        value = newValue
                    }
                }
            ), in: range)
                .accentColor(.blue)
        }
    }
}

// Debug overlay to visualize motion data
struct MotionDebugOverlay: View {
    let x: Double
    let y: Double
    let rotationIntensity: Double
    
    // Calculated properties for visualization
    private var xRotationDegrees: Double { y * rotationIntensity }
    private var yRotationDegrees: Double { -x * rotationIntensity }
    
    // Constants for visualization
    private let indicatorSize: CGFloat = 4
    private let gridSize: CGFloat = 300
    
    var body: some View {
        ZStack {
            
            VStack {
                
                // Visual indicator
                ZStack {
                    // Grid removed here as per instructions to avoid duplicate rendering
                
                    
                    // Position indicator
                    Circle()
                        .fill(.primary)
                        .frame(width: indicatorSize, height: indicatorSize)
                        .position(x: gridSize/2 + CGFloat(x * gridSize/3),
                                  y: gridSize/2 + CGFloat(y * gridSize/3))
                    
                    // Show rotation vector
                    Path { path in
                        path.move(to: CGPoint(x: gridSize/2, y: gridSize/2))
                        path.addLine(to: CGPoint(
                            x: gridSize/2 + CGFloat(x * gridSize/3) * 2,
                            y: gridSize/2 + CGFloat(y * gridSize/3) * 2
                        ))
                    }
                    .stroke(.primary, lineWidth: 1)
                }
                .frame(width: gridSize, height: gridSize)
            }
        }
    }
}


#Preview {
    ContentView()
        .preferredColorScheme(.light)
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}

