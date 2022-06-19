;+
; ;;-------------------------------------------------------------------
; You may copy, distribute and modify Open-LandsatCollection2 under the terms of the GNU
; GENERAL PUBLIC LICENSE Version 2, or any later version.
;
; ; :Description:
;    Describe the procedure.
;     A small plug-in developed based on ENVI5.3/IDL8.5
;     to open Landsat Collection 2 data released by USGS
;
; :Author: xie
; :EnCoding: UTF-8
;-

; ENVI Extension code. Called when the toolbox item is chosen.
; Add the extension to the toolbox. Called automatically on ENVI startup.
pro Open_LandsatC2_extensions_init

  ; Set compile options
  compile_opt IDL2

  ; Get ENVI session
  e = ENVI(/CURRENT)

  ; Add the extension to a subfolder
  e.AddExtension, 'Open Landsat Collection 2', 'Open_LandsatC2', PATH=''
end

pro Open_LandsatC2

  ; Set compile options
  compile_opt IDL2

  ; General error handler
  CATCH, err
  errorshow = 'Sorry to see the error,'+ $
    ' please send the error Information to "xiexj@ecut.edu.cn"'
  if (err ne 0) then begin
    CATCH, /CANCEL
    if OBJ_VALID(e) then $
      e.ReportError, 'ERROR: ' + !error_state.msg + $
      String(13b) + errorshow
    MESSAGE, /RESET
    return
  endif

  ;Get ENVI session
  e = ENVI(/CURRENT)

  ;******************************************
  ; Insert your ENVI Extension code here...
  ;******************************************
  View = e.GetView()
  DataColl = e.Data

  ;设置默认输入文件路径
  prefItem = e.Preferences['directories and files:input directory']
  ENVIInputDir = prefItem.value

  jsonFile = Dialog_pickfile(/read,FILTER = ['*MTL.json'],PATH = ENVIInputDir,$
    TITLE = 'Select a Landsat _MTL.json metadata file')
  if Strlen(jsonFile) eq 0 then return 
  ;jsonFile='D:\Experiment\temp\LC08_C2L2\LC08_L2SP_129044_20150104_20200910_02_T1_MTL.json'

  LandsatC2_Obj = LandsatC2(jsonFile)

  ;; Load Multispectral Imagery (加载多光谱影像)
  outRasters = LandsatC2_Obj.load(QA_Pixel_Raster=QA_Pixel_Raster)
  
  ;; Restore the image to the real surface reflectance (0-1)
  ;;   (scaling:将影像缩放还原为真实地表反射率(0-1))
  outMsRaster = LandsatC2_Obj.Scaling(outPanRaster = outPanRaster,$
    outTirRaster = outTirRaster)
    
  Layer = View.CreateLayer(outMsRaster)  
  
  DataColl.add,[outMsRaster,outTirRaster]
  
  LandsatC2_Obj.Cleanup

end
;