using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.EventSystems;

public class UIElementXR : MonoBehaviour
{
    // Start is called before the first frame update
    public UnityEvent OnXRPointerEnter;
    public UnityEvent OnXRPointerExit;
    private Camera xRCamera;
    void Start()
    {
        xRCamera = CameraPointerManager.Instance.gameObject.GetComponent<Camera>();
    }
    // Update is called once per frame

    public void OnPointerClickXR()
    {
        PointerEventData pointerEvent = PlacePointer();
        ExecuteEvents.Execute(this.gameObject, pointerEvent, ExecuteEvents.pointerClickHandler);

    }
    public void OnPointerEnterXR()
    {
        GazeManager.Instance.SetUpGaze(1.5f);
        OnXRPointerEnter?.Invoke();

        PointerEventData pointerEvent = PlacePointer();
        ExecuteEvents.Execute(this.gameObject, pointerEvent, ExecuteEvents.pointerDownHandler);
    }
    public void OnPointerExitXR()
    {
        GazeManager.Instance.SetUpGaze(2.5f);
        OnXRPointerExit?.Invoke();

        PointerEventData pointerEvent = PlacePointer();
        ExecuteEvents.Execute(this.gameObject, pointerEvent, ExecuteEvents.pointerUpHandler);
    }
    public PointerEventData PlacePointer()
    {
        Vector3 screenPos = xRCamera.WorldToScreenPoint(CameraPointerManager.Instance.hitPoint);
        var pointer = new PointerEventData(EventSystem.current);
        pointer.position = new Vector2(screenPos.x, screenPos.y);
        return pointer;

    }
}
