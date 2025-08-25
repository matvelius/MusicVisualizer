//
//  FractalCompute.metal
//  MusicVisualizer
//
//  Created by Claude Code on 8/24/25.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct AudioData {
    float low;
    float mid;
    float high;
    float overall;
    float time;
};

struct FractalParams {
    uint2 resolution;
    float zoom;
    float2 center;
    uint maxIterations;
    uint fractalType;
    float2 juliaConstant;
    float colorPhase;
    float morphFactor;
};

// MARK: - Utility Functions

float2 complexSquare(float2 z) {
    return float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y);
}

float2 complexMult(float2 a, float2 b) {
    return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

float complexLength(float2 z) {
    return length(z);
}

// MARK: - Fractal Generation Functions

float generateMandelbrot(float2 coord, uint maxIter, constant AudioData& audio) {
    float2 z = float2(0.0, 0.0);
    float2 c = coord;
    
    // Audio-reactive zoom and center adjustment
    float audioZoom = 1.0 + audio.overall * 0.5;
    c *= audioZoom;
    
    for (uint i = 0; i < maxIter; i++) {
        if (length(z) > 2.0) {
            // Smooth iteration count for better color gradients
            return float(i) + 1.0 - log2(log2(length(z)));
        }
        z = complexSquare(z) + c;
    }
    return float(maxIter);
}

float generateJulia(float2 coord, uint maxIter, float2 juliaC, constant AudioData& audio) {
    float2 z = coord * (0.8 + audio.mid * 0.4);
    
    // Audio-reactive Julia constant modulation
    float2 c = juliaC + float2(
        cos(audio.time + audio.low * 6.28318) * 0.1 * audio.overall,
        sin(audio.time * 1.3 + audio.high * 6.28318) * 0.1 * audio.overall
    );
    
    for (uint i = 0; i < maxIter; i++) {
        if (length(z) > 2.0) {
            return float(i) + 1.0 - log2(log2(length(z)));
        }
        z = complexSquare(z) + c;
    }
    return float(maxIter);
}

float generateBurningShip(float2 coord, uint maxIter, constant AudioData& audio) {
    float2 z = float2(0.0, 0.0);
    float2 c = coord;
    
    // Audio-reactive parameters
    float audioScale = 0.8 + audio.high * 0.6;
    c *= audioScale;
    
    for (uint i = 0; i < maxIter; i++) {
        if (length(z) > 2.0) {
            return float(i) + 1.0 - log2(log2(length(z)));
        }
        // Burning ship: use absolute values
        z = float2(abs(z.x), abs(z.y));
        z = complexSquare(z) + c;
    }
    return float(maxIter);
}

float generateSpiral(float2 coord, constant AudioData& audio) {
    float2 c = coord * (1.0 + audio.overall * 0.5);
    float radius = length(c);
    float angle = atan2(c.y, c.x);
    
    // Audio-reactive spiral parameters
    float spiralArms = 5.0 + audio.mid * 3.0;
    float spiralTightness = 8.0 + audio.high * 4.0;
    
    float spiral = sin(angle * spiralArms + radius * spiralTightness + audio.time);
    float rings = cos(radius * 10.0 + audio.time * 2.0) * (0.5 + audio.low * 0.5);
    
    return (spiral + rings) * 0.5 + 0.5;
}

// MARK: - Color Generation

float3 generateColor(float iteration, uint maxIter, uint fractalType, constant AudioData& audio, float colorPhase) {
    float normalizedIter = iteration / float(maxIter);
    
    // Audio-reactive color modulation
    float hueShift = colorPhase + audio.time * 0.1 + audio.overall * 0.3;
    float saturation = 0.7 + audio.mid * 0.3;
    float brightness = 0.5 + normalizedIter * 0.5 + audio.high * 0.2;
    
    // Different color schemes per fractal type
    switch (fractalType) {
        case 0: { // Mandelbrot - Deep, rich colors
            hueShift += normalizedIter * 2.0;
            saturation *= 1.2;
            break;
        }
        case 1: { // Julia - Smooth flowing colors
            hueShift += normalizedIter * 1.5 + audio.low * 0.5;
            brightness = smoothstep(0.0, 1.0, brightness);
            break;
        }
        case 2: { // Burning Ship - Fiery colors
            hueShift = 0.0 + normalizedIter * 0.3; // Reds and oranges
            saturation = min(1.0, saturation * 1.5);
            break;
        }
        default: { // Spiral - Rhythmic colors
            hueShift += sin(normalizedIter * 6.28318 * 3.0) * 0.2;
            brightness = abs(sin(brightness * 3.14159)) * 0.8 + 0.2;
            break;
        }
    }
    
    // Convert HSV to RGB
    float3 hsv = float3(fmod(hueShift, 1.0), clamp(saturation, 0.0, 1.0), clamp(brightness, 0.0, 1.0));
    
    float c = hsv.z * hsv.y;
    float x = c * (1.0 - abs(fmod(hsv.x * 6.0, 2.0) - 1.0));
    float m = hsv.z - c;
    
    float3 rgb;
    if (hsv.x < 1.0/6.0) rgb = float3(c, x, 0);
    else if (hsv.x < 2.0/6.0) rgb = float3(x, c, 0);
    else if (hsv.x < 3.0/6.0) rgb = float3(0, c, x);
    else if (hsv.x < 4.0/6.0) rgb = float3(0, x, c);
    else if (hsv.x < 5.0/6.0) rgb = float3(x, 0, c);
    else rgb = float3(c, 0, x);
    
    return rgb + m;
}

// MARK: - Main Compute Kernel

kernel void fractalComputeShader(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    constant FractalParams& params [[buffer(0)]],
    constant AudioData& audioData [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Early exit for out-of-bounds threads
    if (gid.x >= params.resolution.x || gid.y >= params.resolution.y) {
        return;
    }
    
    // Convert pixel coordinates to complex plane
    float2 coord = (float2(gid) - float2(params.resolution) * 0.5) / float(params.resolution.y) * params.zoom;
    coord += params.center;
    
    // Generate fractal based on type
    float iteration;
    switch (params.fractalType) {
        case 0:
            iteration = generateMandelbrot(coord, params.maxIterations, audioData);
            break;
        case 1:
            iteration = generateJulia(coord, params.maxIterations, params.juliaConstant, audioData);
            break;
        case 2:
            iteration = generateBurningShip(coord, params.maxIterations, audioData);
            break;
        default:
            iteration = generateSpiral(coord, audioData) * float(params.maxIterations);
            break;
    }
    
    // Generate color
    float3 color = generateColor(iteration, params.maxIterations, params.fractalType, audioData, params.colorPhase);
    
    // Apply audio-reactive effects
    float pulseEffect = 1.0 + sin(audioData.time * 4.0 + length(coord) * 2.0) * 0.1 * audioData.overall;
    color *= pulseEffect;
    
    // Write to output texture
    outputTexture.write(float4(color, 1.0), gid);
}

// MARK: - Multi-layer Fractal Compute (for complex visualizations)

kernel void layeredFractalComputeShader(
    texture2d<float, access::write> outputTexture [[texture(0)]],
    constant FractalParams& params [[buffer(0)]],
    constant AudioData& audioData [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Early exit for out-of-bounds threads
    if (gid.x >= params.resolution.x || gid.y >= params.resolution.y) {
        return;
    }
    
    float2 coord = (float2(gid) - float2(params.resolution) * 0.5) / float(params.resolution.y) * params.zoom;
    coord += params.center;
    
    // Generate multiple fractal layers
    float3 finalColor = float3(0.0);
    
    // Layer 1: Base fractal
    float iteration1;
    switch (params.fractalType) {
        case 0:
            iteration1 = generateMandelbrot(coord, params.maxIterations, audioData);
            break;
        case 1:
            iteration1 = generateJulia(coord, params.maxIterations, params.juliaConstant, audioData);
            break;
        case 2:
            iteration1 = generateBurningShip(coord, params.maxIterations, audioData);
            break;
        default:
            iteration1 = generateSpiral(coord, audioData) * float(params.maxIterations);
            break;
    }
    
    float3 color1 = generateColor(iteration1, params.maxIterations, params.fractalType, audioData, params.colorPhase);
    
    // Layer 2: Secondary fractal with different parameters (audio-reactive)
    float2 coord2 = coord * (0.7 + audioData.mid * 0.6) + float2(audioData.low * 0.1, audioData.high * 0.1);
    uint fractalType2 = (params.fractalType + 1) % 4;
    
    float iteration2;
    switch (fractalType2) {
        case 0:
            iteration2 = generateMandelbrot(coord2, params.maxIterations / 2, audioData);
            break;
        case 1:
            iteration2 = generateJulia(coord2, params.maxIterations / 2, params.juliaConstant * 1.2, audioData);
            break;
        case 2:
            iteration2 = generateBurningShip(coord2, params.maxIterations / 2, audioData);
            break;
        default:
            iteration2 = generateSpiral(coord2, audioData) * float(params.maxIterations / 2);
            break;
    }
    
    float3 color2 = generateColor(iteration2, params.maxIterations / 2, fractalType2, audioData, params.colorPhase + 0.3);
    
    // Blend layers based on audio
    float blendFactor = 0.3 + audioData.overall * 0.4;
    finalColor = mix(color1, color2, blendFactor * 0.5);
    
    // Add audio-reactive pulse
    float pulseEffect = 1.0 + sin(audioData.time * 4.0 + length(coord) * 2.0) * 0.1 * audioData.overall;
    finalColor *= pulseEffect;
    
    // Write to output texture
    outputTexture.write(float4(finalColor, 1.0), gid);
}

// MARK: - Full-screen Quad Rendering

struct VertexInput {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOutput {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOutput fullscreenVertexShader(VertexInput in [[stage_in]]) {
    VertexOutput out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 textureFragmentShader(VertexOutput in [[stage_in]],
                                     texture2d<float> inputTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    return inputTexture.sample(textureSampler, in.texCoord);
}