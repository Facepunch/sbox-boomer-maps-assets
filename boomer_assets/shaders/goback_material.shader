//=========================================================================================================================
// Optional
//=========================================================================================================================
HEADER
{
    Description = "Go back - Material";
}

//=========================================================================================================================
// Optional
//=========================================================================================================================
FEATURES
{
    #include "common/features.hlsl"
}

//=========================================================================================================================
// Optional
//=========================================================================================================================
MODES
{
    VrForward();                                                    // Indicates this shader will be used for main rendering
    Depth( S_MODE_DEPTH );                                     // Shader that will be used for shadowing and depth prepass
    ToolsVis( S_MODE_TOOLS_VIS );                                     // Ability to see in the editor
    ToolsWireframe( "vr_tools_wireframe.vfx" );                     // Allows for mat_wireframe to work
    ToolsShadingComplexity( "vr_tools_shading_complexity.vfx" );     // Shows how expensive drawing is in debug view
}

//=========================================================================================================================
COMMON
{
    #include "common/shared.hlsl"

    float g_flAffineAmount< Range(0.0f, 1.0f); Default(0.2f); UiGroup( "Go Back Settings,10/10" ); >;
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

//=========================================================================================================================

VS
{
    #include "common/vertex.hlsl"
    
    int g_RoundToDecimalPlace< Range(0, 10); Default(0); UiGroup( "Go Back Settings,10/10" ); >;
    float g_flSnapScale< Range(1.0f, 5.0f); Default(2.0f); UiGroup( "Go Back Settings,10/10" ); >;

    //
    // Main
    //
    PixelInput MainVs( INSTANCED_SHADER_PARAMS( VS_INPUT i ) )
    {
        PixelInput o = ProcessVertex( i );

        // Vertex Snapping
        float flRound = pow(10, g_RoundToDecimalPlace) * g_flSnapScale;
        o.vPositionPs.xyz = round(o.vPositionPs.xyz * flRound) / flRound;
        
        // Affine texture mapping
        o.vTextureCoords *= lerp(1.0f, o.vPositionPs.w, g_flAffineAmount * 0.005f);

        return FinalizeVertex( o );
    }
}

//=========================================================================================================================

PS
{
    #define CUSTOM_TEXTURE_FILTERING
    SamplerState TextureFiltering < Filter( POINT ); AddressU( WRAP ); AddressV( WRAP ); >;
    StaticCombo( S_MODE_DEPTH, 0..1, Sys( ALL ) );
    BoolAttribute( SupportsMappingDimensions, true );

    #include "common/pixel.hlsl"
    
    #if ( S_MODE_DEPTH )
        #define MainPs Disabled
    #endif
    
    //
    // Main
    //
    float4 MainPs( PixelInput i ) : SV_Target0
    {
        // Affine texture mapping
        i.vTextureCoords.xy /= lerp(1.0f, i.vPositionSs.w, g_flAffineAmount * 0.005f);
        
        Material m = GatherMaterial( i );

        //
        // Declare which shading model we are going to use to calculate lighting
        // If you want to make a generalized shading model, inhering this class
        // Is a good starting point.
        // If not defined in FinalizePixelMaterial, it defaults to the standard
        // Shading model.
        //
        
        ShadingModelValveStandard sm;
        float4 vColor = FinalizePixelMaterial( i, m, sm );

        #if ( S_MODE_TOOLS_VIS )
        {
            float3 vPositionWithOffsetWs = i.vPositionWithOffsetWs.xyz;
            float3 vPositionWs = i.vPositionWithOffsetWs.xyz + g_vHighPrecisionLightingOffsetWs.xyz;
            float3 vNormalWs = normalize( i.vNormalWs.xyz );
            
            ToolsVisInitColor( vColor.rgba );

            ToolsVisHandleFullbright( vColor.rgba, m.Albedo.rgb, vPositionWs.xyz, vNormalWs.xyz );

            ToolsVisHandleAlbedo( vColor.rgba, m.Albedo.rgb );
            ToolsVisHandleReflectivity( vColor.rgba, m.Albedo.rgb );
        }
        #endif

        return vColor;

    }
}
