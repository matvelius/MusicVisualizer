//
//  TreeCompute.metal
//  MusicVisualizer
//
//  Created by Claude Code on 8/25/25.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct GPUTreeNode {
    float2 position;
    int parentIndex; // -1 if no parent
    float thickness;
    float length;
    float angle;
    float age;
    int isVisible; // 0 or 1
    int isRoot; // 0 or 1
    float growthProgress;
    float4 color;
};

struct GPUTreeParams {
    uint nodeCount;
    uint leafCount;
    float currentTime;
    float stageProgress;
    uint currentStage;
    float audioLow;
    float audioMid;
    float audioHigh;
    float audioOverall;
    float2 seedPosition;
    float branchingAngle;
    float baseGrowthRate;
    uint maxNodes;
    uint maxLeaves;
};

struct GPUTreeLeaf {
    float2 position;
    int parentNode;
    float age;
    float maxAge;
    float size;
    float angle;
    float4 color;
    int isAlive;
    int isFalling;
    float2 fallVelocity;
};

// MARK: - Tree Growth Stages

enum TreeGrowthStage : uint {
    SEED = 0,
    ROOTS = 1,
    TRUNK = 2,
    BRANCHES = 3,
    LEAVES = 4,
    MATURE = 5
};

// MARK: - Utility Functions

float random(uint seed, uint index) {
    uint state = seed + index * 1664525u + 1013904223u;
    state ^= state >> 16u;
    state *= 0x85ebca6bu;
    state ^= state >> 13u;
    state *= 0xc2b2ae35u;
    state ^= state >> 16u;
    return float(state) / float(0xffffffffu);
}

float2 randomFloat2(uint seed, uint index) {
    return float2(random(seed, index * 2), random(seed, index * 2 + 1));
}

// MARK: - Tree Growth Compute Kernel

kernel void treeGrowthCompute(
    device GPUTreeNode* nodes [[buffer(0)]],
    constant GPUTreeParams& params [[buffer(1)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= params.maxNodes) return;
    
    // Handle seed stage - make seed visible as it germinates
    if (params.currentStage == SEED && gid == 0) {
        nodes[0].isVisible = 1;
        nodes[0].thickness = params.stageProgress * 0.02;
        nodes[0].growthProgress = params.stageProgress;
        return;
    }
    
    // Handle roots stage - grow roots downward from seed
    if (params.currentStage == ROOTS && gid > 0 && gid <= 5) {
        uint rootIndex = gid;
        if (rootIndex < uint(params.stageProgress * 5.0) + 1) {
            float rootAngle = M_PI_F + float(rootIndex - 1) * (M_PI_F / 3.0) - M_PI_F / 2.0;
            float rootLength = 0.3 * params.stageProgress;
            
            nodes[rootIndex].position = params.seedPosition + float2(
                sin(rootAngle) * rootLength,
                -cos(rootAngle) * rootLength * 0.5
            );
            nodes[rootIndex].parentIndex = 0;
            nodes[rootIndex].thickness = 0.015 * (1.0 - float(rootIndex) * 0.1);
            nodes[rootIndex].angle = rootAngle;
            nodes[rootIndex].isVisible = 1;
            nodes[rootIndex].isRoot = 1;
            nodes[rootIndex].growthProgress = params.stageProgress;
            nodes[rootIndex].color = float4(0.4, 0.2, 0.1, 1.0); // Root brown
        }
        return;
    }
    
    // Handle trunk stage - grow main trunk upward
    if (params.currentStage == TRUNK && gid == 6) { // Trunk node index
        float trunkHeight = params.stageProgress * 0.6;
        nodes[6].position = params.seedPosition + float2(0.0, trunkHeight);
        nodes[6].parentIndex = 0;
        nodes[6].thickness = 0.04;
        nodes[6].angle = 0.0;
        nodes[6].isVisible = 1;
        nodes[6].isRoot = 0;
        nodes[6].growthProgress = params.stageProgress;
        nodes[6].color = float4(0.6, 0.4, 0.2, 1.0); // Trunk brown
        return;
    }
    
    // Handle branches stage - recursive branch growth
    if (params.currentStage == BRANCHES && gid > 6) {
        uint nodeIndex = gid;
        if (nodeIndex < params.nodeCount) {
            // Complex branching logic - simplified for GPU
            // Find parent node and grow branch
            uint parentIndex = nodeIndex / 3 + 6; // Simple parent calculation
            if (parentIndex < nodeIndex && parentIndex < params.nodeCount && nodes[parentIndex].isVisible) {
                float branchLevel = floor(log2(float(nodeIndex - 6)));
                float branchAngle = nodes[parentIndex].angle + 
                                   (float(nodeIndex % 3) - 1.0) * params.branchingAngle * (1.0 + params.audioMid * 0.5);
                float branchLength = 0.2 * pow(0.7, branchLevel) * (0.8 + params.audioHigh * 0.4);
                
                nodes[nodeIndex].position = nodes[parentIndex].position + float2(
                    cos(branchAngle - M_PI_F / 2.0) * branchLength,
                    sin(branchAngle - M_PI_F / 2.0) * branchLength
                );
                nodes[nodeIndex].parentIndex = int(parentIndex);
                nodes[nodeIndex].thickness = nodes[parentIndex].thickness * 0.6;
                nodes[nodeIndex].angle = branchAngle;
                nodes[nodeIndex].isVisible = 1;
                nodes[nodeIndex].isRoot = 0;
                nodes[nodeIndex].growthProgress = params.stageProgress;
                
                // Audio-reactive color mixing
                float4 baseColor = float4(0.6, 0.4, 0.2, 1.0);
                float4 audioColor = float4(
                    0.2 + params.audioHigh * 0.8,
                    0.8 - params.audioMid * 0.3,
                    0.3 + params.audioLow * 0.5,
                    1.0
                );
                float mixFactor = params.audioOverall * 0.3;
                nodes[nodeIndex].color = mix(baseColor, audioColor, mixFactor);
            }
        }
        return;
    }
    
    // Update all visible nodes - age and audio reactivity
    if (gid < params.nodeCount && nodes[gid].isVisible) {
        nodes[gid].age += 1.0 / 60.0; // Assume 60 FPS
        
        // Audio-reactive thickness modulation for living trees
        if (params.currentStage >= BRANCHES) {
            float basethickness = nodes[gid].thickness;
            nodes[gid].thickness = basethickness * (1.0 + sin(params.currentTime * 2.0 + nodes[gid].age) * 0.1 * params.audioOverall);
        }
        
        // Audio-reactive color updates
        if (!nodes[gid].isRoot) {
            float4 baseColor = float4(0.6, 0.4, 0.2, 1.0);
            float hueShift = params.currentTime * 0.1 + params.audioOverall * 0.3;
            float intensity = 0.7 + params.audioMid * 0.3;
            
            nodes[gid].color = float4(
                baseColor.r * intensity * (1.0 + sin(hueShift) * 0.2),
                baseColor.g * intensity * (1.0 + sin(hueShift + 2.0) * 0.2),
                baseColor.b * intensity * (1.0 + sin(hueShift + 4.0) * 0.2),
                1.0
            );
        }
    }
}

// MARK: - Leaf Update Compute Kernel

kernel void leafUpdateCompute(
    device GPUTreeLeaf* leaves [[buffer(0)]],
    device GPUTreeNode* nodes [[buffer(1)]],
    constant GPUTreeParams& params [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= params.maxLeaves) return;
    
    uint leafIndex = gid;
    
    // Generate new leaves during leaves stage
    if (params.currentStage == LEAVES || params.currentStage == MATURE) {
        uint targetLeafCount = uint(params.stageProgress * 50.0) + 10;
        
        if (leafIndex < targetLeafCount && leafIndex < params.leafCount && !leaves[leafIndex].isAlive) {
            // Find a suitable parent node (branch tip)
            uint parentNodeIndex = uint(random(params.currentTime * 1000, leafIndex) * float(params.nodeCount));
            
            // Ensure it's a valid branch node
            if (parentNodeIndex < params.nodeCount && nodes[parentNodeIndex].isVisible && !nodes[parentNodeIndex].isRoot) {
                float2 leafOffset = randomFloat2(leafIndex * 12345, uint(params.currentTime * 1000)) * 0.06 - 0.03;
                
                leaves[leafIndex].position = nodes[parentNodeIndex].position + leafOffset;
                leaves[leafIndex].parentNode = int(parentNodeIndex);
                leaves[leafIndex].age = 0.0;
                leaves[leafIndex].maxAge = 30.0 + (random(leafIndex * 54321, uint(params.currentTime)) - 0.5) * 30.0;
                leaves[leafIndex].size = 0.02 + random(leafIndex * 98765, uint(params.currentTime)) * 0.03;
                leaves[leafIndex].angle = random(leafIndex * 11111, uint(params.currentTime)) * 2.0 * M_PI_F;
                leaves[leafIndex].color = float4(0.2, 0.8, 0.3, 1.0);
                leaves[leafIndex].isAlive = 1;
                leaves[leafIndex].isFalling = 0;
                leaves[leafIndex].fallVelocity = float2(0.0, 0.0);
            }
        }
    }
    
    // Update existing leaves
    if (leafIndex < params.leafCount && leaves[leafIndex].isAlive) {
        leaves[leafIndex].age += 1.0 / 60.0; // Assume 60 FPS
        
        // Check if leaf should start falling
        bool shouldFall = leaves[leafIndex].age > leaves[leafIndex].maxAge || params.audioOverall > 0.9;
        if (shouldFall && !leaves[leafIndex].isFalling) {
            leaves[leafIndex].isFalling = 1;
            leaves[leafIndex].fallVelocity = float2(
                (random(leafIndex * 33333, uint(params.currentTime)) - 0.5) * 0.04,
                -0.05 - random(leafIndex * 44444, uint(params.currentTime)) * 0.03
            );
        }
        
        // Update falling leaves
        if (leaves[leafIndex].isFalling) {
            leaves[leafIndex].position += leaves[leafIndex].fallVelocity * (1.0 / 60.0);
            leaves[leafIndex].fallVelocity.y -= 0.02 * (1.0 / 60.0); // Gravity
            
            // Wind effect based on audio
            leaves[leafIndex].fallVelocity.x += sin(params.currentTime * 2.0 + leaves[leafIndex].age) * 0.01 * params.audioMid;
            
            // Remove leaves that have fallen off screen
            if (leaves[leafIndex].position.y < -1.2) {
                leaves[leafIndex].isAlive = 0;
            }
            
            // Falling leaf color transition
            float fallProgress = min(1.0, leaves[leafIndex].age / leaves[leafIndex].maxAge);
            float4 greenColor = float4(0.2, 0.8, 0.3, 1.0);
            float4 autumnColor = float4(0.8, 0.6, 0.2, 1.0);
            leaves[leafIndex].color = mix(greenColor, autumnColor, fallProgress);
        } else {
            // Living leaf audio reactivity
            float4 baseGreen = float4(0.2, 0.8, 0.3, 1.0);
            float4 audioColor = float4(
                0.2 + params.audioHigh * 0.6,
                0.8,
                0.3 + params.audioLow * 0.4,
                1.0
            );
            float mixFactor = params.audioHigh * 0.4;
            leaves[leafIndex].color = mix(baseGreen, audioColor, mixFactor);
        }
    }
}

// MARK: - Vertex Shader

struct VertexInput {
    float2 position [[attribute(0)]];
};

struct VertexOutput {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
    float size;
    int renderType; // 0 = node, 1 = leaf
};

vertex VertexOutput treeVertexShader(
    VertexInput in [[stage_in]],
    constant GPUTreeNode* nodes [[buffer(1)]],
    constant GPUTreeLeaf* leaves [[buffer(2)]],
    constant GPUTreeParams& params [[buffer(3)]],
    uint instanceID [[instance_id]]
) {
    VertexOutput out;
    
    if (instanceID < params.nodeCount) {
        // Render tree node
        GPUTreeNode node = nodes[instanceID];
        if (node.isVisible) {
            float scale = node.thickness * 20.0;
            float4x4 scaleMatrix = float4x4(
                float4(scale, 0, 0, 0),
                float4(0, scale, 0, 0),
                float4(0, 0, 1, 0),
                float4(0, 0, 0, 1)
            );
            
            float4x4 translationMatrix = float4x4(
                float4(1, 0, 0, 0),
                float4(0, 1, 0, 0),
                float4(0, 0, 1, 0),
                float4(node.position.x, node.position.y, 0, 1)
            );
            
            float4x4 modelMatrix = translationMatrix * scaleMatrix;
            out.position = modelMatrix * float4(in.position, 0.0, 1.0);
            out.texCoord = in.position * 0.5 + 0.5;
            out.color = node.color;
            out.size = node.thickness;
            out.renderType = 0;
        } else {
            // Make invisible nodes off-screen
            out.position = float4(-10.0, -10.0, 0.0, 1.0);
            out.texCoord = float2(0.0, 0.0);
            out.color = float4(0.0, 0.0, 0.0, 0.0);
            out.size = 0.0;
            out.renderType = 0;
        }
    } else {
        // Render leaf (offset by nodeCount)
        uint leafIndex = instanceID - params.nodeCount;
        if (leafIndex < params.leafCount) {
            GPUTreeLeaf leaf = leaves[leafIndex];
            if (leaf.isAlive) {
                float scale = leaf.size * 30.0;
                float cosAngle = cos(leaf.angle);
                float sinAngle = sin(leaf.angle);
                
                float4x4 rotationMatrix = float4x4(
                    float4(cosAngle, -sinAngle, 0, 0),
                    float4(sinAngle, cosAngle, 0, 0),
                    float4(0, 0, 1, 0),
                    float4(0, 0, 0, 1)
                );
                
                float4x4 scaleMatrix = float4x4(
                    float4(scale, 0, 0, 0),
                    float4(0, scale, 0, 0),
                    float4(0, 0, 1, 0),
                    float4(0, 0, 0, 1)
                );
                
                float4x4 translationMatrix = float4x4(
                    float4(1, 0, 0, 0),
                    float4(0, 1, 0, 0),
                    float4(0, 0, 1, 0),
                    float4(leaf.position.x, leaf.position.y, 0, 1)
                );
                
                float4x4 modelMatrix = translationMatrix * rotationMatrix * scaleMatrix;
                out.position = modelMatrix * float4(in.position, 0.0, 1.0);
                out.texCoord = in.position * 0.5 + 0.5;
                out.color = leaf.color;
                out.size = leaf.size;
                out.renderType = 1;
            } else {
                // Make invisible leaves off-screen
                out.position = float4(-10.0, -10.0, 0.0, 1.0);
                out.texCoord = float2(0.0, 0.0);
                out.color = float4(0.0, 0.0, 0.0, 0.0);
                out.size = 0.0;
                out.renderType = 1;
            }
        } else {
            out.position = float4(-10.0, -10.0, 0.0, 1.0);
            out.texCoord = float2(0.0, 0.0);
            out.color = float4(0.0, 0.0, 0.0, 0.0);
            out.size = 0.0;
            out.renderType = 1;
        }
    }
    
    return out;
}

// MARK: - Fragment Shader

fragment float4 treeFragmentShader(VertexOutput in [[stage_in]]) {
    float2 coord = in.texCoord;
    float2 center = coord - 0.5;
    float distFromCenter = length(center) * 2.0;
    
    float4 finalColor = in.color;
    
    if (in.renderType == 0) {
        // Tree node rendering - rectangular branches
        float2 d = abs(center * 2.0) - 0.8;
        float rectDist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
        float alpha = 1.0 - smoothstep(-0.1, 0.1, rectDist);
        
        if (alpha < 0.01) {
            discard_fragment();
        }
        
        finalColor.a *= alpha;
        
        // Add wood texture effect
        float woodGrain = sin(coord.y * 20.0) * 0.1 + 1.0;
        finalColor.rgb *= woodGrain;
        
    } else {
        // Leaf rendering - circular with organic edge
        float leafShape = 1.0 - smoothstep(0.6, 1.0, distFromCenter);
        
        if (leafShape < 0.01) {
            discard_fragment();
        }
        
        finalColor.a *= leafShape;
        
        // Add leaf vein effect
        float vein = abs(center.y) < 0.05 ? 1.2 : 1.0;
        finalColor.rgb *= vein;
    }
    
    // Add subtle glow
    if (distFromCenter < 0.8) {
        float glowIntensity = (0.8 - distFromCenter) / 0.8;
        finalColor.rgb += glowIntensity * 0.1 * finalColor.rgb;
    }
    
    return finalColor;
}