/*
	Clip plane shader for Unity (from the OVAL project).

	Copyright (c) 2019, John Grime, ETL, University of Oklahoma.

	Inspired by Abdullah Aldandarawy (https://github.com/Dandarawy)
*/

Shader "OVAL/ClippingPlaneShader"
{
	Properties
	{
		// Default values for the usual material properties; these will be
		// overidden with values inherited from an existing Unity material 
		// if this shader is added to the material at runtime.
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Albedo (RGB)", 2D) = "white" {}
		_Smoothness("Smoothness", Range(0,1)) = 0.5
		_Metallic("Metallic", Range(0,1)) = 0.0

		// Color for cross-sectional surface of clipped object; effectively
		// the color of the "inside" of the material.
		_CrossColor("Cross Section Color", Color) = (1,1,1,1)

		// Clipping plane defined as surface normal & point on the plane;
		// both os these are in WORLD COORDINATES!
		_PlaneNormal("PlaneNormal",Vector) = (0,1,0,0)
		_PlanePosition("PlanePoint",Vector) = (0,0,0,1)

		// A NON-ZERO reference value for the stencil buffer. You could
		// change this at runtime, but there's no real reason to do so.
		_StencilValue("Stencil Value", Range(1, 255)) = 255
	}

	SubShader
	{
		Tags { "RenderType" = "Opaque" }
	
		//
		// General approach: use fragments from backfaces to "fill
		// in" cross sectional areas exposed by clipping front-facing
		// polygon fragments, without overwriting any existing front-
		// facing fragments that passed the clip test.
		//
		// 1. Set NON-ZERO reference value for stencil buffer. The
		//    stencil buffer is initialized with this value, and
		//    fragments are written only where this reference value
		//    is present in the stencil buffer.
		//
		// 2. Process forward-facing polygon fragments; discard if
		//    fail clip filter, otherwise draw & write ZERO into
		//    the stencil buffer; this ZERO prevents subsequent
		//    overwriting by backface fragments in step 3.
		//
		// 3. Process backward-facing polygon fragments; if clip
		//    filter passed and the reference value is in the
		//    stencil buffer (i.e., NOT ZERO!), write fragment
		//    else discard.
		//

		Stencil
		{
			// NON-ZERO reference value for stencil buffer. This
			// value "allows" a fragment to be drawn.
			Ref [_StencilValue]
			
			// Don't compare new stencil values against existing
			// values in the stencil buffer; just write the new
			// values, for both front- and back-facing fragments.
			CompFront Always
			CompBack Always

			// Fragments always pass the stencil comparison test
			// (we specified "Always" for the comparisons above),
			// but what value do they write to the stencil buffer?
			// Fragments from front-facing polygons write zero
			// (i.e., subsequent back-facing fragments written to
			// the same pixel are ignored). Back-facing fragments
			// replace the existing stencil buffer entry with the
			// reference value (i.e., draws fragment and leaves
			// stencil buffer effectively unchanged).
			PassFront Zero
			PassBack Replace
		}

		//
		// Surface shader for FRONT-FACING polygon fragments.
		//
		// Discard frags on the "wrong" side of the clipping plane,
		// otherwise draw as usual and write 0 to stencil buffer. 
		//

		Cull Back // <- backfaces ignored in the following
		CGPROGRAM

			// Surface shader via "#pragma surface"; parameters are:
			//   1. Use "SurfaceShader()" method as surface shader.
			//   2. Use Unity's "Standard" lighting model.
			//   3. Tell Unity to generate shadows from the results
			//      of our surface shader ("addshadow").
			// Note: using e.g. "fullforwardshadows" instead of
			// "addshadow" can result in shadows being cast from
			// geometry that was "removed" by the clip plane!
			#pragma surface SurfaceShader Standard addshadow

			#pragma target 3.0

			struct Input
			{
				float2 uv_MainTex;
				float3 worldPos;
			};

			fixed4 _Color;
			sampler2D _MainTex;
			half _Smoothness;
			half _Metallic;

			fixed4 _CrossColor;

			fixed3 _PlaneNormal;
			fixed3 _PlanePoint;

			//
			// Consider a plane with surface normal n, containing point r0.
			// Distance, d, of a point r1 to this plane is:
			//
			// d = abs(dot(n,r1-r0)) / abs(n)
			//
			// If n is a unit vector, we can simplify:
			//
			// d = abs(dot(n,r1-r0))
			//   = abs(dot(n,r))
			//
			// where r = r1-r0. Omitting abs() results in SIGNED distance
			// from r1 to the plane: +ve = "above", -ve = "below". We can
			// therefore clip by simply checking if d>0.
			//
			void SurfaceShader(Input IN, inout SurfaceOutputStandard o)
			{
				float d = dot(_PlaneNormal, IN.worldPos - _PlanePoint);
				if (d > 0) discard;

				o.Metallic = _Metallic;
				o.Smoothness = _Smoothness;

				fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
				o.Albedo = c.rgb;
				o.Alpha = c.a;
			}

		ENDCG

		//
		// Draw only backface fragments in regions where the stencil buffer
		// was not set to zero when we drew front-facing polygon fragments.
		// This "colors in" cross sectional areas that we clipped through.
		//
		
		Cull Front // <- only backfaces considered in the following
		CGPROGRAM

			// Use "SurfaceShader()" as the surface shader, and "LightingOff()"
			// for lighting (Unity assumes light routine names prefixed by
			// "Lighting"). Ambient light disabled.
			#pragma surface SurfaceShader Off noambient

			struct Input
			{
				half2 uv_MainTex;
				float3 worldPos;
			};

			fixed4 _Color;
			sampler2D _MainTex;

			fixed4 _CrossColor;

			fixed3 _PlaneNormal;
			fixed3 _PlanePoint;

			// Again we ignore fragments on the "wrong side" of the clipping plane.
			// Othewrwise, use simple unlit appearance for exposed cross-sections.
			void SurfaceShader(Input IN, inout SurfaceOutput o)
			{
				float d = dot(_PlaneNormal, IN.worldPos - _PlanePoint);
				if (d > 0) discard;

				o.Albedo = _CrossColor;
			}

			// No lighting for the fragments used to draw cross-section areas.
			fixed4 LightingOff(SurfaceOutput s, fixed3 lightDir, fixed atten)
			{
				fixed4 c;
				c.rgb = s.Albedo;
				c.a = s.Alpha;
				return c;
			}

		ENDCG
	}
	
	//
	// A "fallback" statement tells Unity where to pull code for shader passes
	// that we need but have not defined. Omitting to provide a fallback leads
	// to any missing passes simply being ignored by Unity. 
	//
	FallBack "Standard"
}
