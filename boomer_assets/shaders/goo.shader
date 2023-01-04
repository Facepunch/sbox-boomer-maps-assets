//=========================================================================================================================
// Optional
//=========================================================================================================================
HEADER
{
	Description = "Goo shader";
}

//=========================================================================================================================
// Optional
//=========================================================================================================================
FEATURES
{
    #include "common/features.hlsl"
}

//=========================================================================================================================
COMMON
{
	#include "common/shared.hlsl"

    float g_flGooScale< Range(0.0f, 5.0f); Default(1.0f); UiGroup("Goo"); >;
    float g_flTravelSpeed< Range(0.0f, 5.0f); Default(0.05f); UiGroup("Goo"); >;
    float2 g_vTravelDirection< Range2(-1.0f, -1.0f, 1.0f, 1.0f); Default2(1.0f, 1.0f); UiGroup("Goo"); >;

    float GetGooTexScale()
    {
        return max( exp(g_flGooScale - 5.0f ), 0.01f );
    }

    float random (in float2 st) {
        return frac(sin(dot(st.xy,
                            float2(12.9898,78.233)))*
            43758.5453123);
    }

    float noise (in float2 st) {
        float2 i = floor(st);
        float2 f = frac(st);

        // Four corners in 2D of a tile
        float a = random(i);
        float b = random(i + float2(1.0, 0.0));
        float c = random(i + float2(0.0, 1.0));
        float d = random(i + float2(1.0, 1.0));

        float2 u = f * f * (3.0 - 2.0 * f);

        return lerp(a, b, u.x) +
                (c - a)* u.y * (1.0 - u.x) +
                (d - b) * u.x * u.y;
    }

    float fbm (in float2 st, uint octaves = 3) {
        // Initial values
        float value = 0.0;
        float amplitude = 0.5f;
        st.x += cos(g_flTime * 0.01f) * 4.0f;
        st.y -= sin(g_flTime * 0.01f) * 3.0f;
        float2 vTravelDir = g_vTravelDirection;
        if( length(vTravelDir) == 0.0f ) vTravelDir = float2(1,-1);

        st += normalize(vTravelDir) * (g_flTime * max( exp(g_flTravelSpeed - 5.0f ), 0.0f ));
        //
        // Loop of octaves
        [loop]
        for (uint i = 0; i < octaves; i++) {
            value.x += amplitude * noise(st);
            st *= 2.;
            amplitude *= .5;
        }
        return value;
    }

    float EvaluateGoo( float2 vTexCoords, uint octaves = 3 )
    {
        return fbm( vTexCoords * 0.5f + fbm( vTexCoords + (g_flTime * 0.2f) + fbm( vTexCoords, octaves ), octaves ), octaves );
    }
}

//=========================================================================================================================

struct VertexInput
{
	#include "common/vertexinput.hlsl"
};

//=========================================================================================================================

struct PixelInput
{
	#include "common/pixelinput.hlsl"
};

struct HullInput
{
    #include "common/pixelinput.hlsl"
};

struct HullOutput
{
    #include "common/pixelinput.hlsl"
};

struct DomainInput
{
	#include "common/pixelinput.hlsl"
};

struct HullPatchConstants
{
	float Edge[3] : SV_TessFactor;
	float Inside : SV_InsideTessFactor;
};

//=========================================================================================================================

VS
{
	#include "common/vertex.hlsl"
	//
	// Main
	//
	PixelInput MainVs( INSTANCED_SHADER_PARAMS( VertexInput i ) )
	{
		PixelInput o = ProcessVertex( i );
		// Add your vertex manipulation functions here
		return o;
	}
}

HS
{
    #include "common/hull.hlsl"

    DynamicCombo( D_MULTIVIEW_INSTANCING, 0..1, Sys( PC ) );
    #define sMaxTesselation 100
    #define fTesselationFalloff 1500

	PatchSize( 3 );
	HullPatchConstants TessellationFunc(InputPatch<HullInput, 3> patch)
	{
		HullPatchConstants o;

		float fTessMax = 1.0f;
		float4 vTess = DistanceBasedTess( patch[0].vPositionWs, patch[1].vPositionWs, patch[2].vPositionWs, 1.0, fTesselationFalloff, sMaxTesselation);
		
		o.Edge[0] = vTess.x;
		o.Edge[1] = vTess.y;
		o.Edge[2] = vTess.z;
		
		o.Inside = vTess.w;
		return o;
	}

	TessellationDomain( "tri" )
    TessellationOutputControlPoints( 3 )
    TessellationOutputTopology( "triangle_cw" )
    TessellationPartitioning( "fractional_odd" )
    TessellationPatchConstantFunc( "TessellationFunc" )
	HullOutput MainHs( InputPatch<HullInput, 3> patch, uint id : SV_OutputControlPointID )
	{
		HullInput i = patch[id];
		HullOutput o;
		
		o.vPositionPs = i.vPositionPs;
		o.vPositionWs = i.vPositionWs;
		o.vNormalWs = i.vNormalWs;
		o.vTextureCoords = i.vTextureCoords;
		o.vVertexColor = i.vVertexColor;
		
		#if ( S_DETAIL_TEXTURE )
			o.vDetailTextureCoords = i.vDetailTextureCoords;
		#endif

		#if ( D_BAKED_LIGHTING_FROM_LIGHTMAP )
			o.vLightmapUV = i.vLightmapUV;
		#endif

		#if ( PS_INPUT_HAS_PER_VERTEX_LIGHTING )
			o.vPerVertexLighting = i.vPerVertexLighting;
		#endif

		#if ( S_SPECULAR )
			o.vCentroidNormalWs = i.vCentroidNormalWs;
		#endif

		#ifdef PS_INPUT_HAS_TANGENT_BASIS
			o.vTangentUWs = i.vTangentUWs;
			o.vTangentVWs = i.vTangentVWs;
		#endif

		#if ( S_USE_PER_VERTEX_CURVATURE )
			o.flSSSCurvature = i.flSSSCurvature;
		#endif

		#if ( D_MULTIVIEW_INSTANCING )
			o.nView = i.nView;
		#endif


		return o;
	}
}

DS
{

    #include "vr_lighting.fxc"
    float g_flGooHeight< Default(32.0f); Range(0.0f, 96.0f); UiGroup("Goo"); >;
    uint g_nGooHeightOctaves< Range(1, 6); UiGroup("Goo"); Default(2); >;

    TessellationDomain( "tri" )
    PixelInput MainDs(HullPatchConstants i, float3 barycentricCoordinates : SV_DomainLocation, const OutputPatch<DomainInput, 3> patch)
	{
		#define Baycentric3Interpolate(fieldName) o.fieldName = \
					patch[0].fieldName * barycentricCoordinates.x + \
					patch[1].fieldName * barycentricCoordinates.y + \
					patch[2].fieldName * barycentricCoordinates.z;

		PixelInput o;

		uint nView = 0;
		uint nSubview = 0;

		#if ( D_MULTIVIEW_INSTANCING > 0 )
			nView = patch[0].nView;
			o.nView = nView;
		#endif
		
		//Baycentric3Interpolate( vPositionPs );
		Baycentric3Interpolate( vPositionWs );
		Baycentric3Interpolate( vNormalWs );
		Baycentric3Interpolate( vTextureCoords );
		Baycentric3Interpolate( vVertexColor );

        #if ( NO_TESSELATION == 0 )
            float flGooOffset = EvaluateGoo( o.vTextureCoords * GetGooTexScale(), g_nGooHeightOctaves );
            o.vPositionWs.z += flGooOffset * g_flGooHeight;//GetWaterVerticalOffset( o.vPositionWs.xy );
		#endif

		o.vPositionPs = Position3WsToPsMultiview( nView, o.vPositionWs );
        o.vPositionWs -= g_vHighPrecisionLightingOffsetWs.xyz;

		//---------------------------------------
		
		#if ( S_DETAIL_TEXTURE )
			Baycentric3Interpolate( vDetailTextureCoords );
		#endif

		#if ( D_BAKED_LIGHTING_FROM_LIGHTMAP )
			Baycentric3Interpolate( vLightmapUV );
		#endif

		#if ( PS_INPUT_HAS_PER_VERTEX_LIGHTING )
			Baycentric3Interpolate( vPerVertexLighting );
		#endif

		#if ( S_SPECULAR )
			Baycentric3Interpolate( vCentroidNormalWs );
		#endif

		#ifdef PS_INPUT_HAS_TANGENT_BASIS
			Baycentric3Interpolate( vTangentUWs );
			Baycentric3Interpolate( vTangentVWs );
		#endif

		#if ( S_USE_PER_VERTEX_CURVATURE )
			Baycentric3Interpolate( flSSSCurvature );
		#endif

		return o;
	}
}

//=========================================================================================================================

PS
{
    #include "common/pixel.hlsl"

    CreateInputTexture2D( TextureGooLut,            Srgb,   8, "",                 "_lut",  "Goo,10/0", Default3( 1.0, 1.0, 1.0 ) );
    CreateTexture2D( g_tGooLut )  < Channel( RGB, None( TextureGooLut ), Linear ); OutputFormat( RGBA8888 ); SrgbRead( false ); >;
    CreateTexture2D( g_tFrameBufferCopyTexture ) < Attribute( "FrameBufferCopyTexture" ); SrgbRead( false ); Filter( MIN_MAG_MIP_LINEAR ); AddressU( MIRROR ); AddressV( MIRROR ); >;
    float4 g_vFBCopyTextureRect < Attribute( "FrameBufferCopyRectangle" ); Default4( 0., 0., 1.0, 1.0 ); >;
    
    BoolAttribute( bWantsFBCopyTexture, true );
    BoolAttribute( translucent, true );
    BoolAttribute( SupportsMappingDimensions, true );
    uint g_nGooColorOctaves< Range(1, 6); UiGroup("Goo"); Default(3); >;
    float g_flColorBoost< Range(0.0f, 5.0f); Default(3.0f); UiGroup("Goo"); >;
    float g_flSpecularBoost< Range(0.0f, 16.0f); Default(8.0f); UiGroup("Goo"); >;
    bool g_bAmbientOcclusion< Default(0); UiGroup("Goo"); >;
    float g_flAmbientOcclusionBoost< Range(0.0f, 16.0f); Default(3.0f); UiGroup("Goo"); >;
    

	//
	// Main
	//
	float4 MainPs( PixelInput i ) : SV_Target0
	{
		float x = EvaluateGoo( i.vTextureCoords * GetGooTexScale(), g_nGooColorOctaves );
        float3 vGooColor = Tex2D( g_tGooLut, float2(x, 0.5f) ).rgb * g_flColorBoost;

        Material m;
        m.Albedo = vGooColor;          
        m.Emission = 0.0f;        
        m.Opacity = 1.0f;         
        m.TintMask = 1.0f;        
        m.Normal = i.vNormalWs;          
        m.Roughness = 1.0f - (saturate((x*x*x) * g_flSpecularBoost) * 0.5f);       
        m.Metalness = 0.0f;
        m.AmbientOcclusion = g_bAmbientOcclusion ? (saturate((x*x)*g_flAmbientOcclusionBoost)) : 1.0f;

        // Unused
        m.Sheen = 0;
        m.SheenRoughness = 0;
        m.Clearcoat = 0;
        m.ClearcoatRoughness = 0;
        m.ClearcoatNormal = 0;
        m.Anisotropy = 0;
        m.AnisotropyRotation = 0;
        m.Thickness = 0;
        m.SubsurfacePower = 0;
        m.SheenColor = 0;
        m.SubsurfaceColor = 0;
        m.Transmission = 0;
        m.Absorption = 0;
        m.IndexOfRefraction = 0;
        m.MicroThickness = 0;

        ShadingModelValveStandard sm;
        return FinalizePixelMaterial( i, m, sm );
	}
}