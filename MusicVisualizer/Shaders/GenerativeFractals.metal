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
};

struct ParticleUniforms {
    float4x4 modelMatrix;
    float4 color;
    float size;
    float complexity;
    int fractalType;
    int generation;
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
    
    return out;
}

// MARK: - Fractal Generation Functions

float2 complexSquare(float2 z) {
    return float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y);
}

float2 complexMult(float2 a, float2 b) {
    return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

float complexLength(float2 z) {
    return sqrt(z.x * z.x + z.y * z.y);
}

// Generate fractal pattern based on type
float generateFractalPattern(float2 coord, int fractalType, float complexity, int generation) {
    float2 c = coord * 2.0 - 1.0; // Convert to [-1,1] range
    
    // Scale based on complexity and generation
    c *= (1.0 + complexity) * (1.0 + float(generation) * 0.1);
    
    switch (fractalType) {
        case 0: { // Mandelbrot-inspired pattern
            float2 z = float2(0.0, 0.0);
            int maxIter = int(20.0 + complexity * 30.0);
            
            for (int i = 0; i < maxIter; i++) {
                if (complexLength(z) > 2.0) {
                    return float(i) / float(maxIter);
                }
                z = complexSquare(z) + c;
            }
            return 1.0;
        }
        
        case 1: { // Julia-inspired pattern
            float2 z = c;
            float2 juliaC = float2(-0.7 + cos(complexity * 3.14159) * 0.3, 
                                   0.27015 + sin(complexity * 2.0) * 0.2);
            int maxIter = int(15.0 + complexity * 25.0);
            
            for (int i = 0; i < maxIter; i++) {
                if (complexLength(z) > 2.0) {
                    return float(i) / float(maxIter);
                }
                z = complexSquare(z) + juliaC;
            }
            return 1.0;
        }
        
        case 2: { // Burning Ship-inspired pattern
            float2 z = float2(0.0, 0.0);
            int maxIter = int(18.0 + complexity * 28.0);
            
            for (int i = 0; i < maxIter; i++) {
                if (complexLength(z) > 2.0) {
                    return float(i) / float(maxIter);
                }
                z = float2(abs(z.x), abs(z.y));
                z = complexSquare(z) + c;
            }
            return 1.0;
        }
        
        default: { // Spiral pattern
            float radius = length(c);
            float angle = atan2(c.y, c.x);
            float spiral = sin(radius * 10.0 + angle * 6.0 + complexity * 5.0);
            return (spiral + 1.0) * 0.5;
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

fragment float4 particleFragmentShader(VertexOut in [[stage_in]]) {
    float2 coord = in.texCoord;
    
    // Create circular mask with soft edges
    float dist = length(coord - 0.5) * 2.0;
    float circleMask = 1.0 - smoothstep(0.8, 1.0, dist);
    
    if (circleMask < 0.01) {
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
    
    // Add pattern-based color variation
    float hueShift = combinedPattern * 0.3 + float(in.generation) * 0.1;
    baseColor.rgb = mix(baseColor.rgb, baseColor.bgr, hueShift);
    
    // Add generation-based transparency
    float generationAlpha = 1.0 - float(in.generation) * 0.1;
    
    // Apply intensity based on pattern
    float intensity = combinedPattern * (0.5 + in.complexity * 0.5);
    
    // Final color
    float4 finalColor = baseColor;
    finalColor.rgb *= intensity;
    finalColor.a *= circleMask * generationAlpha;
    
    // Add glow effect
    if (dist < 0.3) {
        float glowIntensity = (0.3 - dist) / 0.3;
        finalColor.rgb += glowIntensity * 0.2;
    }
    
    return finalColor;
}