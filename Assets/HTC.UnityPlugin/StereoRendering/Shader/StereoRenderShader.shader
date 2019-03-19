//========= Copyright 2016, HTC Corporation. All rights reserved. ===========

Shader "Custom/StereoRenderShader"
{
	Properties
	{
		_LeftEyeTexture("Left Eye Texture", 2D) = "white" {}
	_RightEyeTexture("Right Eye Texture", 2D) = "white" {}
	_Threshold("Lighting Threshold", Range(0,1.0)) = .5

	}

		CGINCLUDE
#include "UnityCG.cginc"
#include "UnityInstancing.cginc"
		ENDCG

		SubShader
	{
		Lighting Off

		Tags{ "RenderType" = "Opaque" }

		//Cull OFF

		CGPROGRAM
#pragma surface surf CustomStandard
#include "UnityPBSLighting.cginc"

#pragma multi_compile __ STEREO_RENDER
#pragma target 3.0

		sampler2D _LeftEyeTexture;
	sampler2D _RightEyeTexture;
	half      _Threshold;


	struct Input
	{
		float2 uv_MainTex;
		float4 screenPos;
	};

	half4 LightingNoLighting(SurfaceOutput s, fixed3 lightDir, fixed atten) {
		return half4(s.Albedo, s.Alpha);
	}
	inline half4 LightingCustomStandard(SurfaceOutputStandard s, half3 viewDir, UnityGI gi)
	{
		s.Normal = normalize(s.Normal);

		half oneMinusReflectivity;
		half3 specColor;
		s.Albedo = DiffuseAndSpecularFromMetallic(s.Albedo, s.Metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

		// shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
		// this is necessary to handle transparency in physically correct way - only diffuse component gets affected by alpha
		half outputAlpha;
		s.Albedo = PreMultiplyAlpha(s.Albedo, s.Alpha, oneMinusReflectivity, /*out*/ outputAlpha);
		//Added a Power Ramp to allow the ability to adjust the lighting through the material
		half4 c = UNITY_BRDF_PBS(s.Albedo, specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);
		c.rgb += UNITY_BRDF_GI(s.Albedo, specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, s.Occlusion, gi);
		c.rgb = lerp(c.rgb,s.Albedo,_Threshold);
		c.a = outputAlpha;
		return c;
	}

	//New Standard Lighting model requires a GI function
	inline void LightingCustomStandard_GI(
		SurfaceOutputStandard s,
		UnityGIInput data,
		inout UnityGI gi)
	{
		gi = UnityGlobalIllumination(data, s.Occlusion, s.Smoothness, s.Normal);
	}
	void surf(Input IN, inout SurfaceOutputStandard o)
	{
		float2 screenUV = IN.screenPos.xy / IN.screenPos.w;

#if UNITY_SINGLE_PASS_STEREO
		float4 scaleOffset = unity_StereoScaleOffset[unity_StereoEyeIndex];
		screenUV = (screenUV - scaleOffset.zw) / scaleOffset.xy;
#endif

		fixed4 color;
		if (unity_StereoEyeIndex == 0)
		{
			fixed4 color = tex2D(_LeftEyeTexture, screenUV);

			o.Albedo = color.xyz;
			//o.Alpha = color.w;
		}
		else
		{
			fixed4 color = tex2D(_RightEyeTexture, screenUV);
			o.Albedo = color.xyz;

			//o.Alpha = color.w;
		}


	}


	ENDCG
	}

		Fallback "Diffuse"
}