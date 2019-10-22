﻿#ifndef MY_SHADOW_INCLUDED
#define MY_SHADOW_INCLUDED

#include "UnityCG.cginc"

#if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
    #ifdef _SEMITRANSPARENT_SHADOWS
        #define SHADOWS_SEMITRANSPARENT 1
    #else
        #define _RENDERING_CUTOUT
    #endif
#endif

#if defined(SHADOWS_SEMITRANSPARENT) || defined(_RENDERING_CUTOUT)
    #ifndef _SMOOTHNESS_ALBEDO
        #define SHADOWS_NEED_UV 1    
    #endif
#endif

float4 _Color;
sampler2D _MainTex;
float4 _MainTex_ST;
float _Cutoff;
sampler3D _DitherMaskLOD;

struct VertexData
{
    float4 position : POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
};

struct InterpolatorsVertex
{
    float4 position : SV_POSITION;
    #if SHADOWS_NEED_UV
        float2 uv : TEXCOORD0;
    #endif
    #ifdef SHADOW_CUBE
        float3 lightVec : TEXCOORD1;
    #endif    
};

struct Interpolators
{
    #if SHADOWS_SEMITRANSPARENT || defined(LOD_FADE_CROSSFADE)
        UNITY_VPOS_TYPE vpos : VPOS;
    #else
        float4 position : SV_POSITION;
    #endif
    #if SHADOWS_NEED_UV
        float2 uv : TEXCOORD0;
    #endif
    #ifdef SHADOW_CUBE
        float3 lightVec : TEXCOORD1;
    #endif    
};

InterpolatorsVertex MyShadowVertexProgram(VertexData v)
{
    InterpolatorsVertex i;
    #ifdef SHADOW_CUBE   
        i.position = UnityObjectToClipPos(v.position);
        i.lightVec = mul(unity_ObjectToWorld, v.position).xyz - _LightPositionRange.xyz;
    #else
        i.position = UnityClipSpaceShadowCasterPos(v.position, v.normal);
        i.position = UnityApplyLinearShadowBias(i.position);
    #endif
    #if SHADOWS_NEED_UV
        i.uv = TRANSFORM_TEX(v.uv, _MainTex);
    #endif
    return i;        
}

float GetAlpha(Interpolators i)
{
    float alpha = _Color.a;
    #if SHADOWS_NEED_UV
        alpha *= tex2D(_MainTex, i.uv.xy).a;
    #endif
    return alpha;
}

float4 MyShadowFragmentProgram(Interpolators i) : SV_TARGET
{
    #ifdef LOD_FADE_CROSSFADE
        UnityApplyDitherCrossFade(i.vpos);
    #endif
    float alpha = GetAlpha(i);
    #ifdef _RENDERING_CUTOUT
        clip(alpha - _Cutoff);
    #endif

    #if SHADOWS_SEMITRANSPARENT
        float dither = tex3D(_DitherMaskLOD, float3(i.vpos.xy * 0.25, alpha * 0.9375)).a;
        clip(dither - 0.01);
    #endif

    #ifdef SHADOW_CUBE
        float depth = length(.i.lightVec)+ unity_LightShadowBias.x;
        depth *= _LightPositionRange.w;
        return UnityEncodeCubeShadowDepth(depth);
    #else
        return 0;
    #endif
}

#endif