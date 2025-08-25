//
//  GenerativeFractals.metal
//  MusicVisualizer
//
//  Created by Claude Code on 7/24/25.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct VertexIn {
    float2 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
    float size;
    float complexity;
    int fractalType;
    int generation;
    int shapeType;
    int nextShapeType;
    float morphProgress;
    float scaleX;
    float scaleY;
    float opacity;
};

struct ParticleUniforms {
    float4x4 modelMatrix;
    float4 color;
    float size;
    float complexity;
    int fractalType;
    int generation;
    int shapeType;
    int nextShapeType;
    float morphProgress;
    float scaleX;
    float scaleY;
    float opacity;
};

// MARK: - Vertex Shader

vertex VertexOut particleVertexShader(VertexIn in [[stage_in]],
                                     constant ParticleUniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    
    // Transform vertex position
    float4 worldPosition = uniforms.modelMatrix * float4(in.position, 0.0, 1.0);
    out.position = worldPosition;
    
    // Pass through attributes
    out.texCoord = in.position * 0.5 + 0.5; // Convert from [-1,1] to [0,1]
    out.color = uniforms.color;
    out.size = uniforms.size;
    out.complexity = uniforms.complexity;
    out.fractalType = uniforms.fractalType;
    out.generation = uniforms.generation;
    out.shapeType = uniforms.shapeType;
    out.nextShapeType = uniforms.nextShapeType;
    out.morphProgress = uniforms.morphProgress;
    out.scaleX = uniforms.scaleX;
    out.scaleY = uniforms.scaleY;
    out.opacity = uniforms.opacity;
    
    return out;
}

// MARK: - Fractal Generation Functions

// Local complex math functions for GenerativeFractals (to avoid conflicts with FractalCompute.metal)
float2 localComplexSquare(float2 z) {
    return float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y);
}

float2 localComplexMult(float2 a, float2 b) {
    return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

float localComplexLength(float2 z) {
    return sqrt(z.x * z.x + z.y * z.y);
}

// Generate fractal pattern based on type
float generateFractalPattern(float2 coord, int fractalType, float complexity, int generation) {
    float2 c = coord * 2.0 - 1.0; // Convert to [-1,1] range
    
    // Scale based on complexity and generation with different scaling for each type
    float baseScale = (1.0 + complexity) * (1.0 + float(generation) * 0.1);
    
    switch (fractalType) {
        case 0: { // Mandelbrot-inspired pattern - Classic recursive structure
            c *= baseScale * 1.2; // Larger scale for more detail
            float2 z = float2(0.0, 0.0);
            int maxIter = int(25.0 + complexity * 35.0);
            float smoothValue = 0.0;
            
            for (int i = 0; i < maxIter; i++) {
                float length_z = localComplexLength(z);
                if (length_z > 4.0) { // Higher escape radius for smoother patterns
                    smoothValue = float(i) - log2(log2(length_z));
                    return smoothValue / float(maxIter);
                }
                z = localComplexSquare(z) + c;
            }
            return 1.0;
        }
        
        case 1: { // Julia-inspired pattern - Flowing organic shapes
            c *= baseScale * 0.8; // Smaller scale for different visual density
            float2 z = c;
            // Dynamic Julia constant that changes with complexity
            float2 juliaC = float2(-0.8 + cos(complexity * 6.28318) * 0.4, 
                                   0.156 + sin(complexity * 4.0) * 0.3);
            int maxIter = int(20.0 + complexity * 30.0);
            float smoothValue = 0.0;
            
            for (int i = 0; i < maxIter; i++) {
                float length_z = localComplexLength(z);
                if (length_z > 4.0) {
                    smoothValue = float(i) - log2(log2(length_z));
                    return smoothValue / float(maxIter);
                }
                z = localComplexSquare(z) + juliaC;
            }
            return 1.0;
        }
        
        case 2: { // Burning Ship-inspired pattern - Sharp angular features
            c *= baseScale * 1.5; // Even larger scale for dramatic effect
            c.y = -abs(c.y); // Flip to get the ship shape
            float2 z = float2(0.0, 0.0);
            int maxIter = int(22.0 + complexity * 32.0);
            float smoothValue = 0.0;
            
            for (int i = 0; i < maxIter; i++) {
                float length_z = localComplexLength(z);
                if (length_z > 4.0) {
                    smoothValue = float(i) - log2(log2(length_z));
                    return smoothValue / float(maxIter);
                }
                // The key difference: absolute values create the "burning" effect
                z = float2(abs(z.x), abs(z.y));
                z = localComplexSquare(z) + c;
            }
            return 1.0;
        }
        
        default: { // Spiral pattern - Geometric and rhythmic
            c *= baseScale * 0.6;
            float radius = length(c);
            float angle = atan2(c.y, c.x);
            float spiral = sin(radius * 12.0 + angle * 8.0 + complexity * 6.0);
            float rings = cos(radius * 15.0 + complexity * 3.0);
            return (spiral + rings) * 0.25 + 0.5;
        }
    }
}

// Generate organic growth patterns
float generateOrganicPattern(float2 coord, float complexity, int generation) {
    float2 c = coord * 2.0 - 1.0;
    
    // Fibonacci spiral pattern
    float goldenRatio = 1.618033988749;
    float angle = atan2(c.y, c.x);
    float radius = length(c);
    
    // Create spiral arms
    float spiralArms = 5.0 + complexity * 3.0;
    float armPattern = sin(angle * spiralArms + radius * 8.0 + float(generation));
    
    // Add branching pattern
    float branchPattern = sin(radius * 15.0 * complexity) * cos(angle * 8.0);
    
    // Combine patterns
    float pattern = (armPattern + branchPattern) * 0.5 + 0.5;
    
    // Add noise for organic feel
    float noise = sin(c.x * 20.0) * cos(c.y * 20.0) * 0.1;
    
    return clamp(pattern + noise, 0.0, 1.0);
}

// MARK: - Fragment Shader

// Shape generation functions
float generateShapeMask(float2 coord, int shapeType) {
    float2 p = coord * 2.0 - 1.0; // Convert to [-1,1] range
    
    switch (shapeType) {
        case 0: { // Circle
            float dist = length(p);
            return 1.0 - smoothstep(0.7, 1.0, dist);
        }
        
        case 1: { // Triangle
            float2 q = abs(p);
            float triangle = max(q.x * 0.866025 + p.y * 0.5, -p.y * 0.5) - 0.43301;
            return 1.0 - smoothstep(-0.1, 0.1, triangle);
        }
        
        case 2: { // Square
            float2 d = abs(p) - 0.7;
            float square = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
            return 1.0 - smoothstep(-0.1, 0.1, square);
        }
        
        case 3: { // Hexagon
            const float3 k = float3(-0.866025404, 0.5, 0.577350269);
            p = abs(p);
            p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
            p -= float2(clamp(p.x, -k.z * 0.7, k.z * 0.7), 0.7);
            float hexagon = length(p) * sign(p.y);
            return 1.0 - smoothstep(-0.1, 0.1, hexagon);
        }
        
        case 4: { // Star
            float angle = atan2(p.y, p.x);
            float radius = length(p);
            float starAngle = fmod(angle + 3.14159, 3.14159 * 0.4) - 3.14159 * 0.2;
            float starRadius = 0.7 * (0.5 + 0.5 * cos(5.0 * starAngle));
            return 1.0 - smoothstep(starRadius - 0.1, starRadius + 0.1, radius);
        }
        
        default:
            return 1.0 - smoothstep(0.7, 1.0, length(p));
    }
}

fragment float4 particleFragmentShader(VertexOut in [[stage_in]]) {
    float2 coord = in.texCoord;
    
    // Generate current and next shape masks
    float currentMask = generateShapeMask(coord, in.shapeType);
    float nextMask = generateShapeMask(coord, in.nextShapeType);
    
    // Interpolate between shapes based on morph progress
    float shapeMask = mix(currentMask, nextMask, in.morphProgress);
    
    if (shapeMask < 0.01) {
        discard_fragment();
    }
    
    // Generate fractal pattern
    float fractalPattern = generateFractalPattern(coord, in.fractalType, in.complexity, in.generation);
    
    // Generate organic growth pattern
    float organicPattern = generateOrganicPattern(coord, in.complexity, in.generation);
    
    // Combine patterns
    float combinedPattern = mix(fractalPattern, organicPattern, 0.6);
    
    // Create color based on pattern and generation
    float4 baseColor = in.color;
    
    // Apply fractal-type-specific color and intensity modifications
    float hueShift = combinedPattern * 0.3 + float(in.generation) * 0.1;
    float intensity = combinedPattern * (0.5 + in.complexity * 0.5);
    
    switch (in.fractalType) {
        case 0: { // Mandelbrot - Rich, deep colors with high contrast
            baseColor.rgb = mix(baseColor.rgb, baseColor.brg, hueShift * 0.8);
            intensity *= 1.2; // Higher intensity for dramatic effect
            baseColor.rgb *= float3(1.1, 0.9, 1.0); // Slight purple/magenta tint
            break;
        }
        case 1: { // Julia - Smooth, flowing colors
            baseColor.rgb = mix(baseColor.rgb, baseColor.gbr, hueShift * 0.6);
            intensity = smoothstep(0.0, 1.0, intensity); // Smoother transitions
            baseColor.rgb *= float3(0.9, 1.1, 1.0); // Slight green/cyan tint
            break;
        }
        case 2: { // Burning Ship - Sharp, fiery colors
            baseColor.rgb = mix(baseColor.rgb, baseColor.rbg, hueShift * 1.2);
            intensity = pow(intensity, 0.7); // More dramatic contrast
            baseColor.rgb *= float3(1.2, 1.0, 0.8); // Orange/red tint for "burning" effect
            break;
        }
        default: { // Spiral - Rhythmic color variations
            baseColor.rgb = mix(baseColor.rgb, baseColor.bgr, hueShift * 0.5);
            intensity = abs(sin(intensity * 3.14159 * 2.0)) * 0.8 + 0.2; // Rhythmic intensity
            break;
        }
    }
    
    // Final color with enhanced blending
    float4 finalColor = baseColor;
    finalColor.rgb *= intensity;
    
    // Use particle opacity for blending
    finalColor.a = shapeMask * in.opacity;
    
    // Add subtle glow effect for better blending
    float2 center = coord - 0.5;
    float distFromCenter = length(center) * 2.0;
    if (distFromCenter < 0.6) {
        float glowIntensity = (0.6 - distFromCenter) / 0.6;
        finalColor.rgb += glowIntensity * 0.15 * finalColor.rgb;
    }
    
    // Add edge softening for better blending
    float edgeSoftness = 1.0 - smoothstep(0.3, 0.8, distFromCenter);
    finalColor.a *= edgeSoftness;
    
    return finalColor;
}

// Note: Full-screen quad shaders moved to FractalCompute.metal to avoid duplication