/*
	Clip plane shader example usage.
	Copyright (c) 2019, John Grime, ETL, University of Oklahoma.
*/

using System.Collections.Generic;
using UnityEngine;

public class ClippingPlaneShaderTest : MonoBehaviour
{
    [Tooltip("Target GameObject")]
    public GameObject target = null;

    [Tooltip("Is the GPU shader enabled for this data?")]
    public bool shaderEnabled = true;

    [Tooltip("Color of exposed regions of cross section after clipping")]
    public Color crossSectionColor = Color.white;

    // Transform to define clip plane via surface normal and surface point.
    // Note that we're using the WORLD COORDINATES, as required by the shader.
    Vector3 planeNormal, planePoint;

    // The clip plane shader.
    Shader clipShader;

    // Internal implementation details
    Dictionary<Renderer, Shader> rendererToShader = new Dictionary<Renderer, Shader>();
    bool shaderEnabledCheck;

    // Walk object tree, storing current shader (if present) for each attached renderer.
    void RebuildShaderMap(GameObject go)
    {
        rendererToShader.Clear();
        _recurse(go.transform);
    }
    void _recurse(Transform t)
    {
        var renderer = t.GetComponent<Renderer>();
        if (renderer != null) rendererToShader[renderer] = renderer.material.shader;

        // Recurse into child GameObjects
        for (int child_i = 0; child_i < t.childCount; child_i++)
        {
            Transform child_t = t.GetChild(child_i);
            _recurse(child_t);
        }
    }

    // Set shaders used by previously stored renderer objects.
    void UpdateShaders( Shader applyThis )
    {
        foreach (var kv in rendererToShader)
        {
            var renderer = kv.Key;
            var shader = kv.Value;

            if (renderer == null) continue;

            renderer.material.shader = (applyThis != null) ? (applyThis) : (shader);

            if (applyThis == null) continue; // don't bother updating shader clip params if not in use.

            //renderer.material.SetInt("_StencilMask", stencilValue); // modification not typically needed!
            renderer.material.SetVector("_CrossColor", crossSectionColor); // modification *probably* not needed!

            // Mofidication almost always needed if attached to e.g. hand controller: use WORLD coords!
            renderer.material.SetVector("_PlaneNormal", planeNormal);
            renderer.material.SetVector("_PlanePoint", planePoint);
        }
    }

    void Start()
    {
        shaderEnabledCheck = shaderEnabled;

        //
        // Default clipping plane parameters.
        //
        planeNormal = new Vector3( 0, 1, 0 );
        planePoint = new Vector3(0, 0, 0);

        //
        // Find shader; should have been placed in an appropriate subdirectory of Assets.
        //
        clipShader = Shader.Find("OVAL/ClippingPlaneShader");
        if (clipShader == null)
            Debug.LogWarning("ClippingPlaneShaderTest: unable to find clip shader!");

        //
        // Add a sphere to demonstrate the clip shader
        //
        var sphere = GameObject.CreatePrimitive( PrimitiveType.Sphere );
        sphere.transform.SetParent( transform );
        sphere.transform.localPosition = new Vector3(0, 0, 0);
        sphere.GetComponent<MeshRenderer>().material.color = Color.blue;

        //
        // Add a plane onto which the sphere can cast shadows
        //
        var plane = GameObject.CreatePrimitive(PrimitiveType.Plane);
        plane.transform.SetParent(transform);
        plane.transform.localRotation = Quaternion.Euler( -90, 0, 0 );
        plane.transform.localPosition = new Vector3( 0, 0, 1 );

        target = sphere;
        RebuildShaderMap(target);
    }

    void Update()
    {
        // Was the shader enabled/disabled since the last frame?
        if (shaderEnabled != shaderEnabledCheck)
        {
            // Ensure we don't leave target in partially clipped state.
            if (!shaderEnabled && target != null) UpdateShaders(applyThis: null);

            shaderEnabledCheck = shaderEnabled;
        }

        if (!shaderEnabled) return;

        planePoint.y = Mathf.Sin(Time.time) * 0.5f;

        //
        // Or attach plane info to e.g. VR controllers to follow
        // indicating devices!
        //
        /*
        var t = rightController.transform;
        planeNormal = t.up;
        planePoint = t.position;
        */

        if (target != null && clipShader != null) UpdateShaders(applyThis: clipShader);
    }
}
