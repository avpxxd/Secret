{@}BackgroundRaytrace.fs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define GAMMA_FACTOR 2
//#define FLIP_SIDED
//uniform mat4 viewMatrix;
//uniform vec3 cameraPosition;

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

uniform vec2 resolution;
uniform float time;
uniform vec3 color0;
uniform vec3 color1;
uniform vec3 color2;
uniform float override;

varying vec2 vUv;

mat3 rotationXY(vec2 angle) {
	float cp = cos(angle.x);
	float sp = sin(angle.x);
	float cy = cos(angle.y);
	float sy = sin(angle.y);

	return mat3(
		cy , 0.0, -sy,
		sy * sp, cp, cy * sp,
		sy * cp, -sp, cy * cp
	);
}

vec3 mixColor(vec3 normal, vec3 baseColor, vec3 addColor, vec3 position, float amount, float falloff) {

    // Compares the color's vector to the ray's vector and fades it out exponentially
    float strength = pow(max(0.0, dot(normal, normalize(position))), 2.0 * falloff);
	return mix(baseColor, addColor, strength * amount);
}

vec3 background(vec3 normal) {

    // Set base color
	vec3 color = color0;

    // Calculate colors' positions
	vec3 mixPos1 = vec3(1.0, 1.0, 0.0);
	vec3 mixPos2 = vec3(-1.0, -1.0, 0.0);

	color = mixColor(normal, color, color1, mixPos1, 1.0, 0.8);
	color = mixColor(normal, color, color2, mixPos2, 1.0, 1.0);

	return color;
}

void main() {
	vec2 uv = vUv;

	vec4 direction = vec4(normalize(vec3(uv, 1.0)), 1.0);

	// Apply camera movement
	direction *= viewMatrix;

    // Animate the rotation
	mat3 rot = rotationXY(vec2(time * 0.0005, time * 0.0003));
	direction.xyz *= rot;

	vec4 sphere = vec4(background(-direction.xyz), 1.0);

	gl_FragColor = sphere * override;

//	float aspect = resolution.x / resolution.y;
//	vec2 center = vec2(0.5, 0.45);
//	vec2 diff = uv - center;
//	diff.x *= aspect;
//	float distance = length(diff);
//	float halo = 1.0 - smoothstep(0.2, 0.5, distance);

//	gl_FragColor.rgb += halo * 0.15;

}{@}BackgroundRaytrace.vs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define VERTEX_TEXTURES
//#define GAMMA_FACTOR 2
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define MAX_BONES 251
//uniform mat4 modelMatrix;
//uniform mat4 modelViewMatrix;
//uniform mat4 projectionMatrix;
//uniform mat4 viewMatrix;
//uniform mat3 normalMatrix;
//uniform vec3 cameraPosition;
//attribute vec3 position;
//attribute vec3 normal;
//attribute vec2 uv;
//#ifdef USE_COLOR
//	attribute vec3 color;
//#endif
//#ifdef USE_MORPHTARGETS
//	attribute vec3 morphTarget0;
//	attribute vec3 morphTarget1;
//	attribute vec3 morphTarget2;
//	attribute vec3 morphTarget3;
//	#ifdef USE_MORPHNORMALS
//		attribute vec3 morphNormal0;
//		attribute vec3 morphNormal1;
//		attribute vec3 morphNormal2;
//		attribute vec3 morphNormal3;
//	#else
//		attribute vec3 morphTarget4;
//		attribute vec3 morphTarget5;
//		attribute vec3 morphTarget6;
//		attribute vec3 morphTarget7;
//	#endif
//#endif
//#ifdef USE_SKINNING
//	attribute vec4 skinIndex;
//	attribute vec4 skinWeight;
//#endif

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

uniform vec2 resolution;
varying vec2 vUv;

void main() {
    vUv = uv;

    gl_Position = vec4(position, 1.0);
}{@}LandGeometry.fs{@}varying vec3 vTransformedNormal;
varying vec4 vmvPosition;
varying vec3 vPosition;
varying vec2 vUv;

uniform vec3 light;
uniform vec3 ambient1;
uniform vec3 ambient2;
uniform sampler2D map;
uniform float shadowMix;
uniform float fadeOut;

#require(range.glsl)
#require(transforms.glsl)

void main() {
    vec3 lVector = transformPosition(light, viewMatrix, vmvPosition);
    float volume = dot(normalize(vTransformedNormal), normalize(lVector));

    volume = range(volume, 0.0, 1.0, 0.0, 1.0);

//    vec3 lightColor = mix(ambient1, ambient2, volume - 0.2);
//    vec3 mixColor = lightColor * volume;
    vec3 color = mix(ambient1, ambient2, volume);

    // FadeOut for myPlanes detail view with earth half visible
    float alpha = mix(1.0, smoothstep(-27.0, -17.0, vmvPosition.y), fadeOut);
    gl_FragColor = vec4(color, alpha);
}{@}LandGeometry.vs{@}varying vec3 vTransformedNormal;
varying vec4 vmvPosition;
varying vec3 vPosition;
varying vec2 vUv;

void main() {
    vPosition = position;
    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
    vTransformedNormal = normalMatrix * normal;
    vmvPosition = mvPosition;
    vUv = uv;
    gl_Position = projectionMatrix * mvPosition;
}{@}OceanGeometry.fs{@}varying vec2 vUv;
varying vec3 vColor;
varying float vAlpha;

uniform sampler2D map;

void main() {
    vec3 color = vColor;

    vec4 shadowColor = texture2D(map, vUv);
    color.rgb *= shadowColor.rgb;

    gl_FragColor = vec4(color, vAlpha);
}{@}OceanGeometry.vs{@}varying vec2 vUv;
varying vec3 vRim;
varying vec3 vColor;
varying float vAlpha;

uniform float time;
uniform vec3 rimColor;
uniform float fadeOut;
uniform vec3 ambient1;
uniform vec3 ambient2;
uniform vec3 light;

attribute float angle;
attribute float radius;
attribute float speed;

#require(refl.vs)
#require(range.glsl)
#require(simplex3d.glsl)
#require(transforms.glsl)

void main() {
    vec3 pos = position;
    vec3 transformedNormal = normalMatrix * normal;

    float radius = length(pos);
    float incl = acos(pos.z / radius);
    float az = atan(pos.y, pos.x);

    float offsetAngle = sin(pos.x + (time * 0.00035)) * 3.2;
    radius += -abs(sin(pos.y + (time * 0.00035)) * 1.0);

    incl += radians(offsetAngle);
    az += radians(offsetAngle);

    vec3 newPos = vec3(0.0);
    newPos.x = radius * sin(incl) * cos(az);
    newPos.y = radius * sin(incl) * sin(az);
    newPos.z = radius * cos(incl);

    pos = newPos;

    vec4 mvPosition = modelViewMatrix * vec4(pos, 1.0);

    vec3 lVector = transformPosition(light, viewMatrix, mvPosition);
    float lVolume = dot(normalize(transformedNormal), normalize(lVector));
    float volume = range(lVolume, 0.0, 1.0, 0.0, 1.05);

    vColor = mix(ambient1, ambient2, volume);

    vUv = uv;
    gl_Position = projectionMatrix * mvPosition;

    vec3 lPos = vec3(0.0, 0.0, 500.0);
    float dProd = 1.0 - dot(normalize(lPos), normalMatrix * normal);
    vec3 rim = clamp(range(dProd, 0.92, 1.0, 0.0, 1.0), 0.0, 1.0) * rimColor * 0.3;

    vColor += rim;

    vAlpha = mix(1.0, smoothstep(-27.0, -17.0, mvPosition.y), fadeOut);
}{@}OceanGeometryBasic.vs{@}varying vec2 vUv;
varying vec3 vRim;
varying vec3 vColor;
varying float vAlpha;

uniform float time;
uniform vec3 rimColor;
uniform float fadeOut;
uniform vec3 ambient1;
uniform vec3 ambient2;
uniform vec3 light;

attribute float angle;
attribute float radius;
attribute float speed;

#require(refl.vs)
#require(range.glsl)
#require(simplex3d.glsl)
#require(transforms.glsl)

void main() {
    vec3 pos = position;
    vec3 transformedNormal = normalMatrix * normal;

    vec4 mvPosition = modelViewMatrix * vec4(pos, 1.0);

    vec3 lVector = transformPosition(light, viewMatrix, mvPosition);
    float lVolume = dot(normalize(transformedNormal), normalize(lVector));
    float volume = range(lVolume, 0.0, 1.0, 0.0, 1.05);

    vColor = mix(ambient1, ambient2, volume);

    vUv = uv;
    gl_Position = projectionMatrix * mvPosition;

    vec3 lPos = vec3(0.0, 0.0, 500.0);
    float dProd = 1.0 - dot(normalize(lPos), normalMatrix * normal);
    vec3 rim = clamp(range(dProd, 0.92, 1.0, 0.0, 1.0), 0.0, 1.0) * rimColor * 0.3;

    vColor += rim;

    vAlpha = mix(1.0, smoothstep(-27.0, -17.0, mvPosition.y), fadeOut);
}{@}OceanReflection.fs{@}uniform samplerCube tCube;

varying vec3 vReflect;
varying vec3 vColor;
varying float vFalloff;

#require(refl.fs)

void main() {
    gl_FragColor = envColor(tCube, vReflect) * 0.4 * vFalloff;
//    gl_FragColor = vec4(vColor, 1.0);
}{@}OceanReflection.vs{@}varying vec3 vReflect;
varying float vFalloff;
varying vec3 vColor;

#require(refl.vs)
#require(range.glsl)

void main() {
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);

    vec3 pos = (modelMatrix * vec4(position, 1.0)).xyz;

    vec3 reflPos = position;
    reflPos.x *= -1.0;
    reflPos.y *= -1.0;

    vReflect = reflection(modelMatrix * vec4(reflPos, 1.0));
    vFalloff = pow(range(abs(pos.z), 0.0, 180.0, 1.0, 0.0), 1.5);

}{@}EarthLocations.fs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define GAMMA_FACTOR 2
//#define FLIP_SIDED
//uniform mat4 viewMatrix;
//uniform vec3 cameraPosition;

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

varying vec2 vUv;

uniform float time;
uniform float alpha;

void main() {
    float y = mod(vUv.y * 3.0 - time * 0.0008, 1.0);
    float ring = smoothstep(0.35, 0.4, y) * smoothstep(0.65, 0.6, y);

    float fadeOut = 1.0 - pow(vUv.y, 2.0);
    gl_FragColor = vec4(1.0, 1.0, 1.0, ring * fadeOut * alpha);
}{@}EarthLocations.vs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define VERTEX_TEXTURES
//#define GAMMA_FACTOR 2
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define MAX_BONES 251
//uniform mat4 modelMatrix;
//uniform mat4 modelViewMatrix;
//uniform mat4 projectionMatrix;
//uniform mat4 viewMatrix;
//uniform mat3 normalMatrix;
//uniform vec3 cameraPosition;
//attribute vec3 position;
//attribute vec3 normal;
//attribute vec2 uv;
//#ifdef USE_COLOR
//	attribute vec3 color;
//#endif
//#ifdef USE_MORPHTARGETS
//	attribute vec3 morphTarget0;
//	attribute vec3 morphTarget1;
//	attribute vec3 morphTarget2;
//	attribute vec3 morphTarget3;
//	#ifdef USE_MORPHNORMALS
//		attribute vec3 morphNormal0;
//		attribute vec3 morphNormal1;
//		attribute vec3 morphNormal2;
//		attribute vec3 morphNormal3;
//	#else
//		attribute vec3 morphTarget4;
//		attribute vec3 morphTarget5;
//		attribute vec3 morphTarget6;
//		attribute vec3 morphTarget7;
//	#endif
//#endif
//#ifdef USE_SKINNING
//	attribute vec4 skinIndex;
//	attribute vec4 skinWeight;
//#endif

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

varying vec2 vUv;

void main() {
    vUv = uv;

    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}{@}EarthLocations2.fs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define GAMMA_FACTOR 2
//#define FLIP_SIDED
//uniform mat4 viewMatrix;
//uniform vec3 cameraPosition;

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

varying vec2 vUv;

uniform float time;
uniform float alpha;

void main() {
    float y = mod(vUv.y * 1.0 - time * 0.0008, 1.0);
    float ring = smoothstep(0.45, 0.5, y) * smoothstep(0.65, 0.6, y);

    float fadeOut = 1.0 - pow(vUv.y, 2.0);
    gl_FragColor = vec4(1.0, 1.0, 1.0, ring * fadeOut * alpha);
}{@}AntimatterCopy.fs{@}uniform sampler2D tDiffuse;

varying vec2 vUv;

void main() {
    gl_FragColor = texture2D(tDiffuse, vUv);
}{@}AntimatterCopy.vs{@}varying vec2 vUv;
void main() {
    vUv = uv;
    gl_Position = vec4(position, 1.0);
}{@}AntimatterPass.vs{@}void main() {
    gl_Position = vec4(position, 1.0);
}{@}AntimatterPosition.vs{@}uniform sampler2D tPos;

#require(antimatter.glsl)

void main() {
    vec4 decodedPos = texture2D(tPos, position.xy);
    vec3 pos = decodedPos.xyz;
    float size = decodedPos.w;
    
    gl_PointSize = size;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
}{@}antimatter.glsl{@}vec3 getData(sampler2D tex, vec2 uv) {
    return texture2D(tex, uv).xyz;
}

vec4 getData4(sampler2D tex, vec2 uv) {
    return texture2D(tex, uv);
}{@}GLShaderFrag.fs{@}//---// START DEFAULT GLSHADER VARIABLES //---//

//precision mediump float;
//uniform sampler2D uTexture;
//uniform float alpha;
//varying vec2 vUv;

//---// END DEFAULT GLSHADER VARIABLES //---//

void main() {
    vec4 color = texture2D(uTexture, vUv);
    gl_FragColor = color;
}{@}GLShaderVert.vs{@}//---// START DEFAULT GLSHADER VARIABLES //---//

//precision mediump float;
//attribute vec4 position;
//attribute vec2 uv;
//uniform vec2 resolution;
//uniform float flipY;
//uniform mat4 transformMatrix;
//varying vec2 vUv;

//vec2 _position(vec2 p) {
//    vec2 zeroToOne = p / resolution;
//    vec2 zeroToTwo = zeroToOne * 2.0;
//    vec2 clipSpace = zeroToTwo - 1.0;
//    return clipSpace * vec2(1.0, -1.0 * flipY);
//}

//---// END DEFAULT GLSHADER VARIABLES //---//

void main() {
    vUv = uv;
    vec4 pos = transformMatrix * position;
    pos.xy = _position(pos.xy);
    gl_Position = pos;
}{@}ShaderMaterialFrag.fs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define GAMMA_FACTOR 2
//#define FLIP_SIDED
//uniform mat4 viewMatrix;
//uniform vec3 cameraPosition;

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

varying vec2 vUv;

void main() {
    gl_FragColor = vec4(vUv, 0.0, 1.0);
}{@}ShaderMaterialVert.vs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define VERTEX_TEXTURES
//#define GAMMA_FACTOR 2
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define MAX_BONES 251
//uniform mat4 modelMatrix;
//uniform mat4 modelViewMatrix;
//uniform mat4 projectionMatrix;
//uniform mat4 viewMatrix;
//uniform mat3 normalMatrix;
//uniform vec3 cameraPosition;
//attribute vec3 position;
//attribute vec3 normal;
//attribute vec2 uv;
//#ifdef USE_COLOR
//	attribute vec3 color;
//#endif
//#ifdef USE_MORPHTARGETS
//	attribute vec3 morphTarget0;
//	attribute vec3 morphTarget1;
//	attribute vec3 morphTarget2;
//	attribute vec3 morphTarget3;
//	#ifdef USE_MORPHNORMALS
//		attribute vec3 morphNormal0;
//		attribute vec3 morphNormal1;
//		attribute vec3 morphNormal2;
//		attribute vec3 morphNormal3;
//	#else
//		attribute vec3 morphTarget4;
//		attribute vec3 morphTarget5;
//		attribute vec3 morphTarget6;
//		attribute vec3 morphTarget7;
//	#endif
//#endif
//#ifdef USE_SKINNING
//	attribute vec4 skinIndex;
//	attribute vec4 skinWeight;
//#endif

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

varying vec2 vUv;

void main() {
    vUv = uv;

    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}{@}curl.glsl{@}#require(simplex3d.glsl)

vec3 snoiseVec3( vec3 x ){
    
    float s  = snoise(vec3( x ));
    float s1 = snoise(vec3( x.y - 19.1 , x.z + 33.4 , x.x + 47.2 ));
    float s2 = snoise(vec3( x.z + 74.2 , x.x - 124.5 , x.y + 99.4 ));
    vec3 c = vec3( s , s1 , s2 );
    return c;
    
}


vec3 curlNoise( vec3 p ){
    
    const float e = 1e-1;
    vec3 dx = vec3( e   , 0.0 , 0.0 );
    vec3 dy = vec3( 0.0 , e   , 0.0 );
    vec3 dz = vec3( 0.0 , 0.0 , e   );
    
    vec3 p_x0 = snoiseVec3( p - dx );
    vec3 p_x1 = snoiseVec3( p + dx );
    vec3 p_y0 = snoiseVec3( p - dy );
    vec3 p_y1 = snoiseVec3( p + dy );
    vec3 p_z0 = snoiseVec3( p - dz );
    vec3 p_z1 = snoiseVec3( p + dz );
    
    float x = p_y1.z - p_y0.z - p_z1.y + p_z0.y;
    float y = p_z1.x - p_z0.x - p_x1.z + p_x0.z;
    float z = p_x1.y - p_x0.y - p_y1.x + p_y0.x;
    
    const float divisor = 1.0 / ( 2.0 * e );
    return normalize( vec3( x , y , z ) * divisor );
}{@}matcap.vs{@}vec2 reflectMatcap(vec3 position, mat4 modelViewMatrix, mat3 normalMatrix, vec3 normal) {
    vec4 p = vec4(position, 1.0);
    
    vec3 e = normalize(vec3(modelViewMatrix * p));
    vec3 n = normalize(normalMatrix * normal);
    vec3 r = reflect(e, n);
    float m = 2.0 * sqrt(
        pow(r.x, 2.0) +
        pow(r.y, 2.0) +
        pow(r.z + 1.0, 2.0)
    );
    
    vec2 uv = r.xy / m + .5;
    
    return uv;
}

vec2 reflectMatcap(vec3 position, mat4 modelViewMatrix, vec3 normal) {
    vec4 p = vec4(position, 1.0);
    
    vec3 e = normalize(vec3(modelViewMatrix * p));
    vec3 n = normalize(normal);
    vec3 r = reflect(e, n);
    float m = 2.0 * sqrt(
                         pow(r.x, 2.0) +
                         pow(r.y, 2.0) +
                         pow(r.z + 1.0, 2.0)
                         );
    
    vec2 uv = r.xy / m + .5;
    
    return uv;
}{@}perlin3d.glsl{@}//
// GLSL textureless classic 3D noise "cnoise",
// with an RSL-style periodic variant "pnoise".
// Author:  Stefan Gustavson (stefan.gustavson@liu.se)
// Version: 2011-10-11
//
// Many thanks to Ian McEwan of Ashima Arts for the
// ideas for permutation and gradient selection.
//
// Copyright (c) 2011 Stefan Gustavson. All rights reserved.
// Distributed under the MIT license. See LICENSE file.
// https://github.com/ashima/webgl-noise
//

vec3 mod289(vec3 x)
{
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289(vec4 x)
{
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x)
{
    return mod289(((x*34.0)+1.0)*x);
}

vec4 taylorInvSqrt(vec4 r)
{
    return 1.79284291400159 - 0.85373472095314 * r;
}

vec3 fade(vec3 t) {
    return t*t*t*(t*(t*6.0-15.0)+10.0);
}

// Classic Perlin noise
float cnoise(vec3 P)
{
    vec3 Pi0 = floor(P); // Integer part for indexing
    vec3 Pi1 = Pi0 + vec3(1.0); // Integer part + 1
    Pi0 = mod289(Pi0);
    Pi1 = mod289(Pi1);
    vec3 Pf0 = fract(P); // Fractional part for interpolation
    vec3 Pf1 = Pf0 - vec3(1.0); // Fractional part - 1.0
    vec4 ix = vec4(Pi0.x, Pi1.x, Pi0.x, Pi1.x);
    vec4 iy = vec4(Pi0.yy, Pi1.yy);
    vec4 iz0 = Pi0.zzzz;
    vec4 iz1 = Pi1.zzzz;
    
    vec4 ixy = permute(permute(ix) + iy);
    vec4 ixy0 = permute(ixy + iz0);
    vec4 ixy1 = permute(ixy + iz1);
    
    vec4 gx0 = ixy0 * (1.0 / 7.0);
    vec4 gy0 = fract(floor(gx0) * (1.0 / 7.0)) - 0.5;
    gx0 = fract(gx0);
    vec4 gz0 = vec4(0.5) - abs(gx0) - abs(gy0);
    vec4 sz0 = step(gz0, vec4(0.0));
    gx0 -= sz0 * (step(0.0, gx0) - 0.5);
    gy0 -= sz0 * (step(0.0, gy0) - 0.5);
    
    vec4 gx1 = ixy1 * (1.0 / 7.0);
    vec4 gy1 = fract(floor(gx1) * (1.0 / 7.0)) - 0.5;
    gx1 = fract(gx1);
    vec4 gz1 = vec4(0.5) - abs(gx1) - abs(gy1);
    vec4 sz1 = step(gz1, vec4(0.0));
    gx1 -= sz1 * (step(0.0, gx1) - 0.5);
    gy1 -= sz1 * (step(0.0, gy1) - 0.5);
    
    vec3 g000 = vec3(gx0.x,gy0.x,gz0.x);
    vec3 g100 = vec3(gx0.y,gy0.y,gz0.y);
    vec3 g010 = vec3(gx0.z,gy0.z,gz0.z);
    vec3 g110 = vec3(gx0.w,gy0.w,gz0.w);
    vec3 g001 = vec3(gx1.x,gy1.x,gz1.x);
    vec3 g101 = vec3(gx1.y,gy1.y,gz1.y);
    vec3 g011 = vec3(gx1.z,gy1.z,gz1.z);
    vec3 g111 = vec3(gx1.w,gy1.w,gz1.w);
    
    vec4 norm0 = taylorInvSqrt(vec4(dot(g000, g000), dot(g010, g010), dot(g100, g100), dot(g110, g110)));
    g000 *= norm0.x;
    g010 *= norm0.y;
    g100 *= norm0.z;
    g110 *= norm0.w;
    vec4 norm1 = taylorInvSqrt(vec4(dot(g001, g001), dot(g011, g011), dot(g101, g101), dot(g111, g111)));
    g001 *= norm1.x;
    g011 *= norm1.y;
    g101 *= norm1.z;
    g111 *= norm1.w;
    
    float n000 = dot(g000, Pf0);
    float n100 = dot(g100, vec3(Pf1.x, Pf0.yz));
    float n010 = dot(g010, vec3(Pf0.x, Pf1.y, Pf0.z));
    float n110 = dot(g110, vec3(Pf1.xy, Pf0.z));
    float n001 = dot(g001, vec3(Pf0.xy, Pf1.z));
    float n101 = dot(g101, vec3(Pf1.x, Pf0.y, Pf1.z));
    float n011 = dot(g011, vec3(Pf0.x, Pf1.yz));
    float n111 = dot(g111, Pf1);
    
    vec3 fade_xyz = fade(Pf0);
    vec4 n_z = mix(vec4(n000, n100, n010, n110), vec4(n001, n101, n011, n111), fade_xyz.z);
    vec2 n_yz = mix(n_z.xy, n_z.zw, fade_xyz.y);
    float n_xyz = mix(n_yz.x, n_yz.y, fade_xyz.x);
    return 2.2 * n_xyz;
}

// Classic Perlin noise, periodic variant
float pnoise(vec3 P, vec3 rep)
{
    vec3 Pi0 = mod(floor(P), rep); // Integer part, modulo period
    vec3 Pi1 = mod(Pi0 + vec3(1.0), rep); // Integer part + 1, mod period
    Pi0 = mod289(Pi0);
    Pi1 = mod289(Pi1);
    vec3 Pf0 = fract(P); // Fractional part for interpolation
    vec3 Pf1 = Pf0 - vec3(1.0); // Fractional part - 1.0
    vec4 ix = vec4(Pi0.x, Pi1.x, Pi0.x, Pi1.x);
    vec4 iy = vec4(Pi0.yy, Pi1.yy);
    vec4 iz0 = Pi0.zzzz;
    vec4 iz1 = Pi1.zzzz;
    
    vec4 ixy = permute(permute(ix) + iy);
    vec4 ixy0 = permute(ixy + iz0);
    vec4 ixy1 = permute(ixy + iz1);
    
    vec4 gx0 = ixy0 * (1.0 / 7.0);
    vec4 gy0 = fract(floor(gx0) * (1.0 / 7.0)) - 0.5;
    gx0 = fract(gx0);
    vec4 gz0 = vec4(0.5) - abs(gx0) - abs(gy0);
    vec4 sz0 = step(gz0, vec4(0.0));
    gx0 -= sz0 * (step(0.0, gx0) - 0.5);
    gy0 -= sz0 * (step(0.0, gy0) - 0.5);
    
    vec4 gx1 = ixy1 * (1.0 / 7.0);
    vec4 gy1 = fract(floor(gx1) * (1.0 / 7.0)) - 0.5;
    gx1 = fract(gx1);
    vec4 gz1 = vec4(0.5) - abs(gx1) - abs(gy1);
    vec4 sz1 = step(gz1, vec4(0.0));
    gx1 -= sz1 * (step(0.0, gx1) - 0.5);
    gy1 -= sz1 * (step(0.0, gy1) - 0.5);
    
    vec3 g000 = vec3(gx0.x,gy0.x,gz0.x);
    vec3 g100 = vec3(gx0.y,gy0.y,gz0.y);
    vec3 g010 = vec3(gx0.z,gy0.z,gz0.z);
    vec3 g110 = vec3(gx0.w,gy0.w,gz0.w);
    vec3 g001 = vec3(gx1.x,gy1.x,gz1.x);
    vec3 g101 = vec3(gx1.y,gy1.y,gz1.y);
    vec3 g011 = vec3(gx1.z,gy1.z,gz1.z);
    vec3 g111 = vec3(gx1.w,gy1.w,gz1.w);
    
    vec4 norm0 = taylorInvSqrt(vec4(dot(g000, g000), dot(g010, g010), dot(g100, g100), dot(g110, g110)));
    g000 *= norm0.x;
    g010 *= norm0.y;
    g100 *= norm0.z;
    g110 *= norm0.w;
    vec4 norm1 = taylorInvSqrt(vec4(dot(g001, g001), dot(g011, g011), dot(g101, g101), dot(g111, g111)));
    g001 *= norm1.x;
    g011 *= norm1.y;
    g101 *= norm1.z;
    g111 *= norm1.w;
    
    float n000 = dot(g000, Pf0);
    float n100 = dot(g100, vec3(Pf1.x, Pf0.yz));
    float n010 = dot(g010, vec3(Pf0.x, Pf1.y, Pf0.z));
    float n110 = dot(g110, vec3(Pf1.xy, Pf0.z));
    float n001 = dot(g001, vec3(Pf0.xy, Pf1.z));
    float n101 = dot(g101, vec3(Pf1.x, Pf0.y, Pf1.z));
    float n011 = dot(g011, vec3(Pf0.x, Pf1.yz));
    float n111 = dot(g111, Pf1);
    
    vec3 fade_xyz = fade(Pf0);
    vec4 n_z = mix(vec4(n000, n100, n010, n110), vec4(n001, n101, n011, n111), fade_xyz.z);
    vec2 n_yz = mix(n_z.xy, n_z.zw, fade_xyz.y);
    float n_xyz = mix(n_yz.x, n_yz.y, fade_xyz.x);
    return 2.2 * n_xyz;
}{@}simplex2d.glsl{@}//
// Description : Array and textureless GLSL 2D simplex noise function.
//      Author : Ian McEwan, Ashima Arts.
//  Maintainer : ijm
//     Lastmod : 20110822 (ijm)
//     License : Copyright (C) 2011 Ashima Arts. All rights reserved.
//               Distributed under the MIT License. See LICENSE file.
//               https://github.com/ashima/webgl-noise
//

vec3 mod289(vec3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec2 mod289(vec2 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 permute(vec3 x) {
    return mod289(((x*34.0)+1.0)*x);
}

float snoise(vec2 v)
{
    const vec4 C = vec4(0.211324865405187,  // (3.0-sqrt(3.0))/6.0
                        0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)
                        -0.577350269189626,  // -1.0 + 2.0 * C.x
                        0.024390243902439); // 1.0 / 41.0
    // First corner
    vec2 i  = floor(v + dot(v, C.yy) );
    vec2 x0 = v -   i + dot(i, C.xx);
    
    // Other corners
    vec2 i1;
    //i1.x = step( x0.y, x0.x ); // x0.x > x0.y ? 1.0 : 0.0
    //i1.y = 1.0 - i1.x;
    i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    // x0 = x0 - 0.0 + 0.0 * C.xx ;
    // x1 = x0 - i1 + 1.0 * C.xx ;
    // x2 = x0 - 1.0 + 2.0 * C.xx ;
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    
    // Permutations
    i = mod289(i); // Avoid truncation effects in permutation
    vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
                     + i.x + vec3(0.0, i1.x, 1.0 ));
    
    vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
    m = m*m ;
    m = m*m ;
    
    // Gradients: 41 points uniformly over a line, mapped onto a diamond.
    // The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)
    
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    
    // Normalise gradients implicitly by scaling m
    // Approximation of: m *= inversesqrt( a0*a0 + h*h );
    m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
    
    // Compute final noise value at P
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}{@}simplex3d.glsl{@}// Description : Array and textureless GLSL 2D/3D/4D simplex
//               noise functions.
//      Author : Ian McEwan, Ashima Arts.
//  Maintainer : ijm
//     Lastmod : 20110822 (ijm)
//     License : Copyright (C) 2011 Ashima Arts. All rights reserved.
//               Distributed under the MIT License. See LICENSE file.
//               https://github.com/ashima/webgl-noise
//

vec3 mod289(vec3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289(vec4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
    return mod289(((x*34.0)+1.0)*x);
}

vec4 taylorInvSqrt(vec4 r) {
    return 1.79284291400159 - 0.85373472095314 * r;
}

float snoise(vec3 v) {
    const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
    const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

    vec3 i  = floor(v + dot(v, C.yyy) );
    vec3 x0 =   v - i + dot(i, C.xxx) ;

    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min( g.xyz, l.zxy );
    vec3 i2 = max( g.xyz, l.zxy );

    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
    vec3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y

    i = mod289(i);
    vec4 p = permute( permute( permute(
          i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
        + i.y + vec4(0.0, i1.y, i2.y, 1.0 ))
        + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

    float n_ = 0.142857142857; // 1.0/7.0
    vec3  ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);  //  mod(p,7*7)

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

    vec4 x = x_ *ns.x + ns.yyyy;
    vec4 y = y_ *ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4( x.xy, y.xy );
    vec4 b1 = vec4( x.zw, y.zw );

    vec4 s0 = floor(b0)*2.0 + 1.0;
    vec4 s1 = floor(b1)*2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
    vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

    vec3 p0 = vec3(a0.xy,h.x);
    vec3 p1 = vec3(a0.zw,h.y);
    vec3 p2 = vec3(a1.xy,h.z);
    vec3 p3 = vec3(a1.zw,h.w);

    vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3) ) );
}

//float surface(vec3 coord) {
//    float n = 0.0;
//    n += 1.0 * abs(snoise(coord));
//    n += 0.5 * abs(snoise(coord * 2.0));
//    n += 0.25 * abs(snoise(coord * 4.0));
//    n += 0.125 * abs(snoise(coord * 8.0));
//    float rn = 1.0 - n;
//    return rn * rn;
//}{@}normalmap.glsl{@}vec3 unpackNormal( vec2 vUv, vec3 eye_pos, vec3 surf_norm, sampler2D normal_map, float intensity, float scale ) {
    surf_norm = normalize(surf_norm);

    vec3 q0 = dFdx( eye_pos.xyz );
    vec3 q1 = dFdy( eye_pos.xyz );
    vec2 st0 = dFdx( vUv.st );
    vec2 st1 = dFdy( vUv.st );

    vec3 S = normalize( q0 * st1.t - q1 * st0.t );
    vec3 T = normalize( -q0 * st1.s + q1 * st0.s );
    vec3 N = normalize( surf_norm );

    vec3 mapN = texture2D( normal_map, vUv * scale ).xyz * 2.0 - 1.0;
    mapN.xy *= intensity;
    mat3 tsn = mat3( S, T, N );
    return normalize( tsn * mapN );
}{@}range.glsl{@}float range(float oldValue, float oldMin, float oldMax, float newMin, float newMax) {
    float oldRange = oldMax - oldMin;
    float newRange = newMax - newMin;
    return (((oldValue - oldMin) * newRange) / oldRange) + newMin;
}{@}refl.fs{@}vec3 reflection(vec3 worldPosition, vec3 normal) {
    vec3 cameraToVertex = normalize(worldPosition - cameraPosition);
    
    return reflect(cameraToVertex, normal);
}

vec3 refraction(vec3 worldPosition, vec3 normal, float rRatio) {
    vec3 cameraToVertex = normalize(worldPosition - cameraPosition);
    
    return refract(cameraToVertex, normal, rRatio);
}

vec4 envColor(samplerCube map, vec3 vec) {
    float flipNormal = 1.0;
    return textureCube(map, flipNormal * vec3(-1.0 * vec.x, vec.yz));
}{@}refl.vs{@}vec3 inverseTransformDirection(in vec3 normal, in mat4 matrix) {
    return normalize((matrix * vec4(normal, 0.0) * matrix).xyz);
}

vec3 reflection(vec4 worldPosition) {
    vec3 transformedNormal = normalMatrix * normal;
    vec3 cameraToVertex = normalize(worldPosition.xyz - cameraPosition);
    vec3 worldNormal = inverseTransformDirection(transformedNormal, viewMatrix);
    
    return reflect(cameraToVertex, worldNormal);
}

vec3 refraction(vec4 worldPosition, float refractionRatio) {
    vec3 transformedNormal = normalMatrix * normal;
    vec3 cameraToVertex = normalize(worldPosition.xyz - cameraPosition);
    vec3 worldNormal = inverseTransformDirection(transformedNormal, viewMatrix);
    
    return refract(cameraToVertex, worldNormal, refractionRatio);
}{@}TiltShift.fs{@}varying vec2 vUv;

uniform sampler2D tDiffuse;
uniform float blur;
uniform float gradientBlur;
uniform vec2 start;
uniform vec2 end;
uniform vec2 delta;
uniform vec2 texSize;
uniform float far;
uniform sampler2D tDepth;
uniform vec3 earth;

#require(range.glsl)

float random(vec3 scale, float seed) {
    return fract(sin(dot(gl_FragCoord.xyz + seed, scale)) * 43758.5453 + seed);
}

vec3 reconstructPositionFromDepth(vec2 uv) {
    vec4 depth = texture2D(tDepth, uv);
    vec3 pos = (depth.xyz * (far * 2.0)) - far;
    return pos;
}


void main(void) {
    vec4 color = vec4(0.0);
    float total = 0.0;

    vec3 pos = reconstructPositionFromDepth(vUv);
    float dist = length(pos - earth);

//    float blurAmount = clamp(range(dist, 120.0, 500.0, 0.0, 1.0), 0.0, 1.0);
//    blurAmount *= clamp(range(pos.z, 120.0, 200.0, 1.0, 0.0), 0.0, 1.0);

//    if (pos.z < 0.0) blurAmount = 0.0;

    float blurAmount = clamp(range(pos.z, 400.0, -120.0, 1.0, 0.0), 0.0, 1.0);

    float offset = random(vec3(12.9898, 78.233, 151.7182), 0.0);
    vec2 normal = normalize(vec2(start.y - end.y, end.x - start.x));
    float radius = smoothstep(0.0, 1.0, abs(dot(vUv * texSize - start, normal)) / gradientBlur) * (blurAmount * blur);
    
    for (float t = -4.0; t <= 4.0; t++)
    {
        float percent = (t + offset - 0.5) / 4.0;
        float weight = 1.0 - abs(percent);
        vec2 lookupUV = vUv + delta / texSize * percent * radius;
//        if (reconstructPositionFromDepth(lookupUV).z - pos.z < 10.0 ) {
            vec4 samp = texture2D(tDiffuse, lookupUV);
            samp.rgb *= samp.a;
            color += samp * weight;
            total += weight;
//        }
    }
    
    gl_FragColor = color / total;
    gl_FragColor.rgb /= gl_FragColor.a + 0.00001;
}{@}transforms.glsl{@}vec3 transformPosition(vec3 pos, mat4 viewMat, vec3 mvPos) {
    vec4 worldPosition = viewMat * vec4(pos, 1.0);
    return worldPosition.xyz - mvPos;
}

vec3 transformPosition(vec3 pos, mat4 viewMat, vec4 mvPos) {
    vec4 worldPosition = viewMat * vec4(pos, 1.0);
    return worldPosition.xyz - mvPos.xyz;
}{@}Net.fs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define GAMMA_FACTOR 2
//#define FLIP_SIDED
//uniform mat4 viewMatrix;
//uniform vec3 cameraPosition;

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

uniform float alpha;

void main() {
    gl_FragColor = vec4(1.0, 1.0, 1.0, 0.5);
    gl_FragColor.a *= alpha;
}{@}Net.vs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define VERTEX_TEXTURES
//#define GAMMA_FACTOR 2
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define MAX_BONES 251
//uniform mat4 modelMatrix;
//uniform mat4 modelViewMatrix;
//uniform mat4 projectionMatrix;
//uniform mat4 viewMatrix;
//uniform mat3 normalMatrix;
//uniform vec3 cameraPosition;
//attribute vec3 position;
//attribute vec3 normal;
//attribute vec2 uv;
//#ifdef USE_COLOR
//	attribute vec3 color;
//#endif
//#ifdef USE_MORPHTARGETS
//	attribute vec3 morphTarget0;
//	attribute vec3 morphTarget1;
//	attribute vec3 morphTarget2;
//	attribute vec3 morphTarget3;
//	#ifdef USE_MORPHNORMALS
//		attribute vec3 morphNormal0;
//		attribute vec3 morphNormal1;
//		attribute vec3 morphNormal2;
//		attribute vec3 morphNormal3;
//	#else
//		attribute vec3 morphTarget4;
//		attribute vec3 morphTarget5;
//		attribute vec3 morphTarget6;
//		attribute vec3 morphTarget7;
//	#endif
//#endif
//#ifdef USE_SKINNING
//	attribute vec4 skinIndex;
//	attribute vec4 skinWeight;
//#endif

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

uniform vec3 control;
uniform float flaccid;
uniform float sway;
uniform float time;

void main() {
    vec3 pos = position;

    float falloff = max(0.0, 1.0 - length(pos - control) / abs(control.x));
    float falloffCurve = pow(falloff, 2.0);

    float angle = flaccid * 0.5 * falloffCurve;
    mat2 rot = mat2(
        cos(angle), -sin(angle),
        sin(angle),  cos(angle)
    );
    pos.xy *= rot;

    pos.y += falloff * -8.0 * flaccid + falloffCurve * 5.0;
    pos.x += falloff * 10.0 * flaccid;

    // Sway
    pos.z += falloffCurve * 5.0 * sway;

    pos.z += falloffCurve * 1.0 * sin(time * 0.002);
    pos.y += falloffCurve * 1.0 * sin(time * 0.002 + 1.57);

    gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
}{@}NetBase.fs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define GAMMA_FACTOR 2
//#define FLIP_SIDED
//uniform mat4 viewMatrix;
//uniform vec3 cameraPosition;

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

varying vec2 mUV;
varying float fade;
uniform float alpha;
uniform sampler2D tMatcap;

void main() {
    gl_FragColor = texture2D(tMatcap, mUV) * 1.2;
    gl_FragColor.a = fade * alpha;
}{@}NetBase.vs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define VERTEX_TEXTURES
//#define GAMMA_FACTOR 2
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define MAX_BONES 251
//uniform mat4 modelMatrix;
//uniform mat4 modelViewMatrix;
//uniform mat4 projectionMatrix;
//uniform mat4 viewMatrix;
//uniform mat3 normalMatrix;
//uniform vec3 cameraPosition;
//attribute vec3 position;
//attribute vec3 normal;
//attribute vec2 uv;
//#ifdef USE_COLOR
//	attribute vec3 color;
//#endif
//#ifdef USE_MORPHTARGETS
//	attribute vec3 morphTarget0;
//	attribute vec3 morphTarget1;
//	attribute vec3 morphTarget2;
//	attribute vec3 morphTarget3;
//	#ifdef USE_MORPHNORMALS
//		attribute vec3 morphNormal0;
//		attribute vec3 morphNormal1;
//		attribute vec3 morphNormal2;
//		attribute vec3 morphNormal3;
//	#else
//		attribute vec3 morphTarget4;
//		attribute vec3 morphTarget5;
//		attribute vec3 morphTarget6;
//		attribute vec3 morphTarget7;
//	#endif
//#endif
//#ifdef USE_SKINNING
//	attribute vec4 skinIndex;
//	attribute vec4 skinWeight;
//#endif

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

varying float fade;
varying vec2 mUV;

#require(range.glsl)
#require(matcap.vs)

void main() {
    fade = range(position.y, -18.0, -10.0, 0.0, 1.0);

    mUV = reflectMatcap(position, modelViewMatrix, normalMatrix, normal);

    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}{@}OrbitPlane.fs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define GAMMA_FACTOR 2
//#define FLIP_SIDED
//uniform mat4 viewMatrix;
//uniform vec3 cameraPosition;

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

varying vec2 vUV;
varying vec2 vUVMatCap;
uniform sampler2D tMatCap;
uniform float alpha;

void main() {
    gl_FragColor = texture2D(tMatCap, vUVMatCap);
    gl_FragColor.a *= alpha;
}{@}OrbitPlane.vs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define VERTEX_TEXTURES
//#define GAMMA_FACTOR 2
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define MAX_BONES 251
//uniform mat4 modelMatrix;
//uniform mat4 modelViewMatrix;
//uniform mat4 projectionMatrix;
//uniform mat4 viewMatrix;
//uniform mat3 normalMatrix;
//uniform vec3 cameraPosition;
//attribute vec3 position;
//attribute vec3 normal;
//attribute vec2 uv;
//#ifdef USE_COLOR
//	attribute vec3 color;
//#endif
//#ifdef USE_MORPHTARGETS
//	attribute vec3 morphTarget0;
//	attribute vec3 morphTarget1;
//	attribute vec3 morphTarget2;
//	attribute vec3 morphTarget3;
//	#ifdef USE_MORPHNORMALS
//		attribute vec3 morphNormal0;
//		attribute vec3 morphNormal1;
//		attribute vec3 morphNormal2;
//		attribute vec3 morphNormal3;
//	#else
//		attribute vec3 morphTarget4;
//		attribute vec3 morphTarget5;
//		attribute vec3 morphTarget6;
//		attribute vec3 morphTarget7;
//	#endif
//#endif
//#ifdef USE_SKINNING
//	attribute vec4 skinIndex;
//	attribute vec4 skinWeight;
//#endif

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

uniform float time;

varying vec2 vUV;
varying vec2 vUVMatCap;

#require(matcap.vs)

void main() {

    // Pass UVs for texture maps
    vUV = uv;

    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);

    // Pass UVs for matCap based on normals
    vUVMatCap = reflectMatcap(gl_Position.xyz, modelViewMatrix, normal);
}{@}PlaneFold.fs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define GAMMA_FACTOR 2
//#define FLIP_SIDED
//uniform mat4 viewMatrix;
//uniform vec3 cameraPosition;

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

varying vec2 vUV;
varying vec2 vUVMatCap;
varying vec3 vViewPosition;
varying mat4 vMVMatrix;
varying vec3 vPosition;

uniform sampler2D tMatCap;
uniform sampler2D tFold;
uniform sampler2D tStamp;
uniform sampler2D tBorder;
uniform sampler2D tSplat;
uniform float fIntensity;
uniform float fAge;
uniform float fFade;
uniform vec3 splatColor;
uniform float splatAlpha;
uniform float splatScale;
uniform vec2 splatPosition;
uniform vec3 stripColor;
uniform float stripAlpha;

#require(matcap.vs)

vec3 blend(vec4 src, vec4 dst) {
//    return (src.rgb * src.a) + (dst.rgb * (1.0 – src.a));
    return src.rgb + (dst.rgb * (1.0 - src.a));
}

vec3 blendSplat(vec4 src, vec4 dst) {
//    return (src.rgb * src.a) + (dst.rgb * (1.0 – src.a));
   return src.rgb + (dst.rgb * (1.0 - src.a));
}

void main() {

    vec3 fdx = vec3(dFdx(vViewPosition.x), dFdx(vViewPosition.y), dFdx(vViewPosition.z));
    vec3 fdy = vec3(dFdy(vViewPosition.x), dFdy(vViewPosition.y), dFdy(vViewPosition.z));
    vec3 normal = normalize(cross(fdx,fdy));

    vec2 uvMatCap = reflectMatcap(vPosition, vMVMatrix, normal);

    vec4 matCap = texture2D(tMatCap, uvMatCap);
    vec4 folded = texture2D(tFold, vUV);
    vec4 border = texture2D(tBorder, vUV);
    vec4 stamp = texture2D(tStamp, vUV);
    stamp.a *= fIntensity * fFade;
    stamp.rgb *= stamp.a;

    border.rgb = mix(vec3(1.0), border.rgb, fIntensity * fFade);
    folded.rgb = mix(vec3(1.0), folded.rgb, 0.2 * fAge * fFade);

    vec2 scale = vec2(splatScale, splatScale * 21.0 / 30.0);
    vec2 uvSplat = vUV;
    uvSplat /= scale;
    uvSplat += vec2(0.5);
    uvSplat -= splatPosition / scale;
    vec4 splat = texture2D(tSplat, uvSplat);
    splat.a *= splatAlpha;
    splat.rgb *= splat.a;
    splat.rgb *= splatColor;

    gl_FragColor = matCap;
    gl_FragColor = mix(matCap, folded, 0.8);
    gl_FragColor *= border;
    gl_FragColor.rgb = blend(stamp, gl_FragColor);
    gl_FragColor.rgb = blendSplat(splat, gl_FragColor);

    gl_FragColor.rgb = mix(gl_FragColor.rgb, stripColor + vec3(0.2, 0.2, 0.3), smoothstep(0.96999, 0.97, vUV.y) * stripAlpha * 0.8 * (1.0 - fFade));
//    gl_FragColor.rgb = mix(gl_FragColor.rgb, stripColor, smoothstep(0.96999, 0.97, vUV.y) * stripAlpha * 0.5);
}



{@}PlaneFold.vs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define VERTEX_TEXTURES
//#define GAMMA_FACTOR 2
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define MAX_BONES 251
//uniform mat4 modelMatrix;
//uniform mat4 modelViewMatrix;
//uniform mat4 projectionMatrix;
//uniform mat4 viewMatrix;
//uniform mat3 normalMatrix;
//uniform vec3 cameraPosition;
//attribute vec3 position;
//attribute vec3 normal;
//attribute vec2 uv;
//#ifdef USE_COLOR
//	attribute vec3 color;
//#endif
//#ifdef USE_MORPHTARGETS
//	attribute vec3 morphTarget0;
//	attribute vec3 morphTarget1;
//	attribute vec3 morphTarget2;
//	attribute vec3 morphTarget3;
//	#ifdef USE_MORPHNORMALS
//		attribute vec3 morphNormal0;
//		attribute vec3 morphNormal1;
//		attribute vec3 morphNormal2;
//		attribute vec3 morphNormal3;
//	#else
//		attribute vec3 morphTarget4;
//		attribute vec3 morphTarget5;
//		attribute vec3 morphTarget6;
//		attribute vec3 morphTarget7;
//	#endif
//#endif
//#ifdef USE_SKINNING
//	attribute vec4 skinIndex;
//	attribute vec4 skinWeight;
//#endif

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

varying vec2 vUV;
varying vec3 vViewPosition;
varying mat4 vMVMatrix;
varying vec3 vPosition;

uniform float morphTargetInfluences[4];

void main() {
    vMVMatrix = modelViewMatrix;
    vUV = uv;

    vec3 morphed = vec3( 0.0 );
    morphed += ( morphTarget0 - position ) * morphTargetInfluences[0];
    morphed += ( morphTarget1 - position ) * morphTargetInfluences[1];
    morphed += ( morphTarget2 - position ) * morphTargetInfluences[2];
    morphed += ( morphTarget3 - position ) * morphTargetInfluences[3];
    morphed += position;

    vec4 mvPosition = modelViewMatrix * vec4(morphed, 1.0);
    vViewPosition = -mvPosition.xyz;

    gl_Position = projectionMatrix * modelViewMatrix * vec4(morphed, 1.0);

    vPosition = gl_Position.xyz;
}{@}InstanceDepth.fs{@}varying vec3 vColor;

void main() {
    gl_FragColor = vec4(vColor, 1.0);
}{@}InstanceDepth.vs{@}attribute vec3 offset;
attribute vec4 orientation;
attribute vec3 random;
attribute float released;

uniform float time;
uniform float far;

varying vec2 vUV;
varying vec2 vUVMatCap;
varying float vReleased;
varying vec3 vColor;

#require(matcap.vs)

void main() {

    // Pass UVs for texture maps
    vUV = uv;

    vReleased = released;

    // Update vertex positions based on offset and orientation buffers
    vec3 pos = position;

    pos *= random;

    vec4 or = orientation;
    vec3 vcV = cross(or.xyz, pos);
    pos = vcV * (2.0 * or.w) + (cross(or.xyz, vcV) * 2.0 + pos);
    pos += offset;

    pos.x += (1.0 - released) * 10000.0;
    pos.y += (1.0 - released) * 10000.0;

    // Update normals as well for matcap to work
    vec3 nml = normal;
    vec3 vcn = cross(or.xyz, normal);
    nml = vcn * (2.0 * or.w) + (cross(or.xyz, vcn) * 2.0 + nml);

    gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);

    vec3 depthPos = (modelMatrix * vec4(pos, 1.0)).xyz;
    depthPos += far;
    depthPos /= far * 2.0;
    vColor = depthPos;
}{@}PlaneCPUInstance.fs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define GAMMA_FACTOR 2
//#define FLIP_SIDED
//uniform mat4 viewMatrix;
//uniform vec3 cameraPosition;

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

uniform sampler2D tMatCap;
uniform float alpha;

varying vec2 vUV;
varying vec2 vUVMatCap;
varying float vReleased;

void main() {
    gl_FragColor = texture2D(tMatCap, vUVMatCap);
    gl_FragColor.a *= alpha;
    gl_FragColor.a *= vReleased;
}{@}PlaneCPUInstance.vs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define VERTEX_TEXTURES
//#define GAMMA_FACTOR 2
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define MAX_BONES 251
//uniform mat4 modelMatrix;
//uniform mat4 modelViewMatrix;
//uniform mat4 projectionMatrix;
//uniform mat4 viewMatrix;
//uniform mat3 normalMatrix;
//uniform vec3 cameraPosition;
//attribute vec3 position;
//attribute vec3 normal;
//attribute vec2 uv;
//#ifdef USE_COLOR
//	attribute vec3 color;
//#endif
//#ifdef USE_MORPHTARGETS
//	attribute vec3 morphTarget0;
//	attribute vec3 morphTarget1;
//	attribute vec3 morphTarget2;
//	attribute vec3 morphTarget3;
//	#ifdef USE_MORPHNORMALS
//		attribute vec3 morphNormal0;
//		attribute vec3 morphNormal1;
//		attribute vec3 morphNormal2;
//		attribute vec3 morphNormal3;
//	#else
//		attribute vec3 morphTarget4;
//		attribute vec3 morphTarget5;
//		attribute vec3 morphTarget6;
//		attribute vec3 morphTarget7;
//	#endif
//#endif
//#ifdef USE_SKINNING
//	attribute vec4 skinIndex;
//	attribute vec4 skinWeight;
//#endif

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

attribute vec3 offset;
attribute vec4 orientation;
attribute vec3 random;
attribute float released;

uniform float time;

varying vec2 vUV;
varying vec2 vUVMatCap;
varying float vReleased;

#require(matcap.vs)

void main() {

    // Pass UVs for texture maps
    vUV = uv;

    vReleased = released;

    // Update vertex positions based on offset and orientation buffers
    vec3 pos = position;

    pos *= random;

    vec4 or = orientation;
    vec3 vcV = cross(or.xyz, pos);
    pos = vcV * (2.0 * or.w) + (cross(or.xyz, vcV) * 2.0 + pos);
    pos += offset;

    pos.x += (1.0 - released) * 10000.0;

    // Update normals as well for matcap to work
    vec3 nml = normal;
    vec3 vcn = cross(or.xyz, normal);
    nml = vcn * (2.0 * or.w) + (cross(or.xyz, vcn) * 2.0 + nml);

    gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);

    // Pass UVs for matCap based on normals
    vUVMatCap = reflectMatcap(gl_Position.xyz, modelViewMatrix, nml);
}{@}PlaneGPGPUInstance.fs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define GAMMA_FACTOR 2
//#define FLIP_SIDED
//uniform mat4 viewMatrix;
//uniform vec3 cameraPosition;

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

varying vec2 vUV;
varying vec2 vUVMatCap;

uniform sampler2D tMatCap;
uniform sampler2D texturePosition;
uniform sampler2D textureVelocity;

void main() {
    gl_FragColor = texture2D(textureVelocity, vUV);
//    gl_FragColor = texture2D(tMatCap, vUVMatCap);
}{@}PlaneGPGPUInstance.vs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define VERTEX_TEXTURES
//#define GAMMA_FACTOR 2
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define MAX_BONES 251
//uniform mat4 modelMatrix;
//uniform mat4 modelViewMatrix;
//uniform mat4 projectionMatrix;
//uniform mat4 viewMatrix;
//uniform mat3 normalMatrix;
//uniform vec3 cameraPosition;
//attribute vec3 position;
//attribute vec3 normal;
//attribute vec2 uv;
//#ifdef USE_COLOR
//	attribute vec3 color;
//#endif
//#ifdef USE_MORPHTARGETS
//	attribute vec3 morphTarget0;
//	attribute vec3 morphTarget1;
//	attribute vec3 morphTarget2;
//	attribute vec3 morphTarget3;
//	#ifdef USE_MORPHNORMALS
//		attribute vec3 morphNormal0;
//		attribute vec3 morphNormal1;
//		attribute vec3 morphNormal2;
//		attribute vec3 morphNormal3;
//	#else
//		attribute vec3 morphTarget4;
//		attribute vec3 morphTarget5;
//		attribute vec3 morphTarget6;
//		attribute vec3 morphTarget7;
//	#endif
//#endif
//#ifdef USE_SKINNING
//	attribute vec4 skinIndex;
//	attribute vec4 skinWeight;
//#endif

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

attribute vec2 coords;

varying vec2 vUV;
varying vec2 vUVMatCap;

uniform sampler2D texturePosition;
uniform sampler2D textureVelocity;

#require(matcap.vs)

void main() {

    // Pass UVs for texture maps
    vUV = uv;



//    vec4 tmpPos = texture2D(texturePosition, coords);
//    vec3 pos = tmpPos.xyz;
//    vec3 velocity = normalize(texture2D(textureVelocity, coords).xyz);
//
//    vec3 newPosition = position;
//    newPosition = mat3(modelMatrix) * newPosition;
//
//    // From velocity, calculate rotation matrices
//    velocity.z *= -1.0;
//    float xz = length(velocity.xz);
//    float xyz = 1.0;
//    float x = sqrt(1.0 - velocity.y * velocity.y);
//
//    float cosry = velocity.x / xz;
//    float sinry = velocity.z / xz;
//
//    float cosrz = x / xyz;
//    float sinrz = velocity.y / xyz;
//
//    mat3 maty =  mat3(
//        cosry, 0, -sinry,
//        0    , 1, 0     ,
//        sinry, 0, cosry
//    );
//
//    mat3 matz =  mat3(
//        cosrz , sinrz, 0,
//        -sinrz, cosrz, 0,
//        0     , 0    , 1
//    );
//
//    newPosition =  maty * matz * newPosition;
//    newPosition += pos;
//
//    gl_Position = projectionMatrix *  viewMatrix  * vec4(newPosition, 1.0);





    vec3 offset = texture2D(texturePosition, coords).xyz;





    // Update vertex positions based on offset and orientation buffers
    vec3 pos = position;
//    vec3 vcV = cross(orientation.xyz, pos);
//    pos = vcV * (2.0 * orientation.w) + (cross(orientation.xyz, vcV) * 2.0 + pos);
    pos += offset;
    pos.xy += coords * 100.0;

    // Update normals as well for matcap to work
    vec3 nml = normal;
//    vec3 vcn = cross(orientation.xyz, normal);
//    nml = vcn * (2.0 * orientation.w) + (cross(orientation.xyz, vcn) * 2.0 + nml);

    gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);

    // Pass UVs for matCap based on normals
    vUVMatCap = reflectMatcap(gl_Position.xyz, modelViewMatrix, nml);
//    vUVMatCap = reflectMatcap(gl_Position.xyz, modelViewMatrix, normal);
}{@}Curl.fs{@}uniform sampler2D tOrigin;
uniform sampler2D tProperties;

//tValues, tPrev (sampler2D) predefined
//time (float) predefined

void main() {
    vec2 uv = getUV();
    vec4 pos = getData4(tInput, uv);
    
    vec3 properties = getData(tProperties, uv);
    
    float range = properties.x;
    float speed = properties.y;
    
    vec3 p = pos.xyz + 1.0;
    
    gl_FragColor = vec4(p, pos.a);
}{@}Flocking.fs{@}uniform float dT; // about 0.016
uniform float seperationDistance; // 20
uniform float alignmentDistance; // 40
uniform float cohesionDistance; //
uniform float maxVel;
uniform float centerPower;
uniform float forceMultiplier;

uniform vec3 predator;
uniform float predatorRepelPower;
uniform float predatorRepelRadius;
uniform float centerForce;

const int width = @SIZE;
const int height = width;

const float PI = 3.141592653589793;
const float PI_2 = PI * 2.0;
// const float VISION = PI * 0.55;

const float UPPER_BOUNDS = 400.0;
const float LOWER_BOUNDS = -UPPER_BOUNDS;

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void main()	{
    float zoneRadius = 40.0;
    float zoneRadiusSquared = zoneRadius * zoneRadius;
    
    float separationThresh = 0.45;
    float alignmentThresh = 0.65;
    
    zoneRadius = seperationDistance + alignmentDistance + cohesionDistance;
    separationThresh = seperationDistance / zoneRadius;
    alignmentThresh = ( seperationDistance + alignmentDistance ) / zoneRadius;
    zoneRadiusSquared = zoneRadius * zoneRadius;
    
    
    vec2 uv = getUV();
    vec3 fPos, fVel;
    
    vec4 sample = getData4(tValues, uv);
    vec3 pos = sample.xyz;
    float whichCoral = sample.w;
    vec3 oPos = getData4(tPrev, uv).xyz;
    
    vec3 vel = pos - oPos;
    
    vec3 force = vec3( 0. );
    
    float dist;
    vec3 dir; // direction
    float distSquared;
    
    float seperationSquared = seperationDistance * seperationDistance;
    float cohesionSquared = cohesionDistance * cohesionDistance;
    
    float f;
    float percent;
    
    
    // Attract flocks to the center
    vec3 central = predator;
    dir = pos - central;
    dist = length( dir );
    //dir.y *= 2.5;
    force -= normalize( dir ) * dist * dist * centerPower * .0001;
    
    // Moves Flock from center
    if( dist < predatorRepelRadius ){
        
        force += normalize( dir ) * predatorRepelPower;
        
        
    }
    
    
    // Checking information of other birds
    // This is something that Older GPUs REALLLY hate!
    
    for ( int y = 0; y < height; y++ ) {
        for ( int x = 0; x < width; x++ ) {
            if ( float(x) == gl_FragCoord.x && float(y) == gl_FragCoord.y ) continue;
            
            vec2 lookup = vec2( float(x) / fSize,  float(y) / fSize ) ;
            fPos = texture2D(tValues, lookup ).xyz;
            
            dir = fPos - pos;
            dist = length(dir);
            distSquared = dist * dist;
            
            if ( dist > 0.0 && distSquared < zoneRadiusSquared ) {
                
                percent = distSquared / zoneRadiusSquared;
                
                if ( percent < separationThresh ) { // low
                    
                    // Separation - Move apart for comfort
                    f = (separationThresh / percent - 1.0);
                    force -= normalize(dir) * f;
                    
                } else if ( percent < alignmentThresh ) { // high
                    
                    // Alignment - fly the same direction
                    float threshDelta = alignmentThresh - separationThresh;
                    float adjustedPercent = ( percent - separationThresh ) / threshDelta;
                    
                    
                    vec3 oFPos =  texture2D(tPrev, lookup ).xyz;
                    
                    fVel = fPos - oFPos;
                    
                    f = ( 0.5 - cos( adjustedPercent * PI_2 ) * 0.5 + 0.5 );
                    force += normalize(fVel) * f;
                    
                } else {
                    
                    // Attraction / Cohesion - move closer
                    float threshDelta = 1.0 - alignmentThresh;
                    float adjustedPercent = ( percent - alignmentThresh ) / threshDelta;
                    
                    f = ( 0.5 - ( cos( adjustedPercent * PI_2 ) * -0.5 + 0.5 ) );
                    
                    force += normalize(dir) * f;
                    
                }
                
            }
            
        }
        
    }
    
    vel += force * forceMultiplier * dT;
    
    vel *= .95; // dampening
    
    // Speed Limits
    if ( length( vel ) > maxVel ) {
        vel = normalize( vel ) * maxVel;
    }
    
    gl_FragColor = vec4( pos + vel, sample.w);
    
}{@}ParticleOutput.fs{@}varying vec3 vColor;

void main() {
    gl_FragColor = vec4(vColor, 1.0);
}{@}ParticleOutput.vs{@}uniform sampler2D tPos;

varying vec3 vColor;

attribute vec3 color;

#require(antimatter.glsl)

void main() {
    vec2 uv = position.xy;
    vec4 decodedPos = texture2D(tPos, uv);
    vec3 pos = decodedPos.xyz;
    float size = decodedPos.w;
    
    //everything outside of this stays the same, generally
    vColor = color;
    /////////
    
    vec4 mvPosition = modelViewMatrix * vec4(pos, 1.0);
    gl_PointSize = size * (1000.0 / length(mvPosition.xyz));
    gl_Position = projectionMatrix * mvPosition;
}

///only need to do this if you want to do anything in the vertex shader{@}ShadowTest.fs{@}#chunk(common);
#chunk(lights_pars);
#chunk(shadowmap_pars_fragment);

varying vec3 vNormal;

void main() {
    
    float shadowValue = 1.0;
#if ( NUM_DIR_LIGHTS > 0 )
    
    IncidentLight directLight;
    DirectionalLight directionalLight;
    
    for ( int i = 0; i < NUM_DIR_LIGHTS; i ++ ) {
        
        directionalLight = directionalLights[ i ];
        
        shadowValue = getShadow( directionalShadowMap[ i ], directionalLight.shadowMapSize, directionalLight.shadowBias, directionalLight.shadowRadius, vDirectionalShadowCoord[ i ] );
        
        if (dot(directionalLight.direction, vNormal) <= 0.002) {
            shadowValue = 1.0;
        }
    }
    
#endif
    
    gl_FragColor = vec4(vec3(shadowValue) + 0.8, 1.0);
}{@}ShadowTest.vs{@}
#chunk(shadowmap_pars_vertex);

varying vec3 vNormal;

void main() {
    vec4 worldPosition = modelMatrix * vec4(position, 1.0);
    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
    gl_Position = projectionMatrix * mvPosition;
    
    vNormal = normalMatrix * normal;
    
    #chunk(shadowmap_vertex);
}{@}Test.fs{@}void main() {
    vec2 uv = getUV();
    vec4 pos = getData4(tInput, uv);
    
    vec3 p = pos.xyz;

//    p -= 1.0;
    
    gl_FragColor = vec4(p, pos.w);
}{@}DOFPass.fs{@}uniform sampler2D tDiffuse;
uniform sampler2D tDepth;
uniform float far;
uniform float blur;
uniform vec2 resolution;

varying vec2 vUv;

#require(range.glsl)

vec4 blur13(sampler2D image, vec2 uv, vec2 resolution, vec2 direction) {
    vec4 color = vec4(0.0);
    vec2 off1 = vec2(1.411764705882353) * direction;
    vec2 off2 = vec2(3.2941176470588234) * direction;
    vec2 off3 = vec2(5.176470588235294) * direction;
    color += texture2D(image, uv) * 0.1964825501511404;
    color += texture2D(image, uv + (off1 / resolution)) * 0.2969069646728344;
    color += texture2D(image, uv - (off1 / resolution)) * 0.2969069646728344;
    color += texture2D(image, uv + (off2 / resolution)) * 0.09447039785044732;
    color += texture2D(image, uv - (off2 / resolution)) * 0.09447039785044732;
    color += texture2D(image, uv + (off3 / resolution)) * 0.010381362401148057;
    color += texture2D(image, uv - (off3 / resolution)) * 0.010381362401148057;
    return color;
}

vec4 blur9(sampler2D image, vec2 uv, vec2 resolution, vec2 direction) {
    vec4 color = vec4(0.0);
    vec2 off1 = vec2(1.3846153846) * direction;
    vec2 off2 = vec2(3.2307692308) * direction;
    color += texture2D(image, uv) * 0.2270270270;
    color += texture2D(image, uv + (off1 / resolution)) * 0.3162162162;
    color += texture2D(image, uv - (off1 / resolution)) * 0.3162162162;
    color += texture2D(image, uv + (off2 / resolution)) * 0.0702702703;
    color += texture2D(image, uv - (off2 / resolution)) * 0.0702702703;
    return color;
}

vec4 blur5(sampler2D image, vec2 uv, vec2 resolution, vec2 direction) {
    vec4 color = vec4(0.0);
    vec2 off1 = vec2(1.3333333333333333) * direction;
    color += texture2D(image, uv) * 0.29411764705882354;
    color += texture2D(image, uv + (off1 / resolution)) * 0.35294117647058826;
    color += texture2D(image, uv - (off1 / resolution)) * 0.35294117647058826;
    return color;
}


vec3 reconstructPositionFromDepth() {
    vec4 depth = texture2D(tDepth, vUv);
    vec3 pos = (depth.xyz * (far * 2.0)) - far;
    return pos;
}

void main() {
    /*vec3 pos = reconstructPositionFromDepth();
    
    float amt = smoothstep(-500.0, -4000.0, pos.z);
    amt += smoothstep(0.0, 500.0, pos.z);
    
    vec2 dist = vUv - vec2(0.5, 0.5);
    vec2 dir = normalize(dist);
    
    vec4 texel = texture2D(tDiffuse, vUv);
    
    vec4 dof = blur5(tDiffuse, vUv, resolution, amt * blur * dir);
    vec4 bloom = texel * clamp(range(length(texel.rgb) / 1.0, 0.7, 1.0, 0.0, 0.5), 0.0, 0.5);
    
    gl_FragColor = dof;*/

    gl_FragColor = texture2D(tDepth, vUv);
}{@}DepthOverride.fs{@}varying vec3 vColor;

void main() {
    gl_FragColor = vec4(vColor, 1.0);
}{@}DepthOverride.vs{@}uniform float far;

varying vec3 vColor;

void main() {
    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
    gl_Position = projectionMatrix * mvPosition;

    vec3 pos = (modelMatrix * vec4(position, 1.0)).xyz;
    pos += far;
    pos /= far * 2.0;
    vColor = pos;
}{@}Stats.fs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define GAMMA_FACTOR 2
//#define FLIP_SIDED
//uniform mat4 viewMatrix;
//uniform vec3 cameraPosition;

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

uniform sampler2D map;
uniform float opacity;
uniform float threshold;
uniform float count;

varying vec2 vUv;
varying float vLetter;

float aastep(float threshold, float value) {
    #ifdef GL_OES_standard_derivatives
        float afwidth = length(vec2(dFdx(value), dFdy(value))) * 0.70710678118654757;
        return smoothstep(threshold-afwidth, threshold+afwidth, value);
    #else
        return step(threshold, value);
    #endif
}

#require(range.glsl)

void main() {
    vec4 texColor = texture2D(map, vUv);
    float sdf = texColor.a;
//    float alpha = aastep(threshold, sdf) * opacity;
    float index = vLetter / count;
    float transition = max(0.0, min(1.0, range(opacity, index * 0.7, index * 0.7 + 0.3, 0.0, 1.0)));
    float alpha = sdf * transition;
    gl_FragColor = vec4(vec3(1.0), alpha);

//    vec4 letter = getLetter();

    if (alpha < 0.001) discard;

//    gl_FragColor = texColor;
//    gl_FragColor = vec4(vUv, 0.0, 1.0);
//    gl_FragColor = vec4(vLetter / count, 0.0, 0.0, 1.0);
}{@}Stats.vs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define VERTEX_TEXTURES
//#define GAMMA_FACTOR 2
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define MAX_BONES 251
//uniform mat4 modelMatrix;
//uniform mat4 modelViewMatrix;
//uniform mat4 projectionMatrix;
//uniform mat4 viewMatrix;
//uniform mat3 normalMatrix;
//uniform vec3 cameraPosition;
//attribute vec3 position;
//attribute vec3 normal;
//attribute vec2 uv;
//#ifdef USE_COLOR
//	attribute vec3 color;
//#endif
//#ifdef USE_MORPHTARGETS
//	attribute vec3 morphTarget0;
//	attribute vec3 morphTarget1;
//	attribute vec3 morphTarget2;
//	attribute vec3 morphTarget3;
//	#ifdef USE_MORPHNORMALS
//		attribute vec3 morphNormal0;
//		attribute vec3 morphNormal1;
//		attribute vec3 morphNormal2;
//		attribute vec3 morphNormal3;
//	#else
//		attribute vec3 morphTarget4;
//		attribute vec3 morphTarget5;
//		attribute vec3 morphTarget6;
//		attribute vec3 morphTarget7;
//	#endif
//#endif
//#ifdef USE_SKINNING
//	attribute vec4 skinIndex;
//	attribute vec4 skinWeight;
//#endif

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//


attribute vec3 offset;
attribute vec4 orientation;
attribute float scale;
attribute float letter;
uniform float opacity;
uniform float yOffset;
uniform float count;

varying vec2 vUv;
varying float vLetter;

#require(range.glsl)

void main() {
    vUv = uv;
    vLetter = letter;

    vec3 pos = position;

    float index = vLetter / count;
    float transition = pow(1.0 - max(0.0, min(1.0, range(opacity, index * 0.6, index * 0.6 + 0.4, 0.0, 1.0))), 2.0);
    pos.y += yOffset * transition;
    pos.z += yOffset * 2.0 * transition;

    gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
}{@}ThrownPlane.fs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define GAMMA_FACTOR 2
//#define FLIP_SIDED
//uniform mat4 viewMatrix;
//uniform vec3 cameraPosition;

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

varying vec2 vUV;
varying vec2 vUVMatCap;
uniform sampler2D tMatCap;
uniform float alpha;
uniform vec3 stripColor;

void main() {
    gl_FragColor = texture2D(tMatCap, vUVMatCap);
    gl_FragColor.a *= alpha;

    gl_FragColor.rgb = mix(gl_FragColor.rgb, stripColor + vec3(0.26, 0.26, 0.36), smoothstep(0.1, 0.09, vUV.y) * 0.7);
}{@}ThrownPlane.vs{@}//---// START DEFAULT SHADERMATERIAL VARIABLES //---//

//precision highp float;
//precision highp int;
//#define SHADER_NAME ShaderMaterial
//#define VERTEX_TEXTURES
//#define GAMMA_FACTOR 2
//#define MAX_DIR_LIGHTS 1
//#define MAX_POINT_LIGHTS 0
//#define MAX_SPOT_LIGHTS 0
//#define MAX_HEMI_LIGHTS 0
//#define MAX_SHADOWS 0
//#define MAX_BONES 251
//uniform mat4 modelMatrix;
//uniform mat4 modelViewMatrix;
//uniform mat4 projectionMatrix;
//uniform mat4 viewMatrix;
//uniform mat3 normalMatrix;
//uniform vec3 cameraPosition;
//attribute vec3 position;
//attribute vec3 normal;
//attribute vec2 uv;
//#ifdef USE_COLOR
//	attribute vec3 color;
//#endif
//#ifdef USE_MORPHTARGETS
//	attribute vec3 morphTarget0;
//	attribute vec3 morphTarget1;
//	attribute vec3 morphTarget2;
//	attribute vec3 morphTarget3;
//	#ifdef USE_MORPHNORMALS
//		attribute vec3 morphNormal0;
//		attribute vec3 morphNormal1;
//		attribute vec3 morphNormal2;
//		attribute vec3 morphNormal3;
//	#else
//		attribute vec3 morphTarget4;
//		attribute vec3 morphTarget5;
//		attribute vec3 morphTarget6;
//		attribute vec3 morphTarget7;
//	#endif
//#endif
//#ifdef USE_SKINNING
//	attribute vec4 skinIndex;
//	attribute vec4 skinWeight;
//#endif

//---// END DEFAULT SHADERMATERIAL VARIABLES //---//

uniform float time;

varying vec2 vUV;
varying vec2 vUVMatCap;

#require(matcap.vs)

void main() {

    // Pass UVs for texture maps
    vUV = uv;

    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);

    // Pass UVs for matCap based on normals
    vUVMatCap = reflectMatcap(gl_Position.xyz, modelViewMatrix, normal);
}