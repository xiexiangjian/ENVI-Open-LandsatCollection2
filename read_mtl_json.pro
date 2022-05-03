; Add the extension to the toolbox. Called automatically on ENVI startup.
pro Read_MTL_json_extensions_init

  ; Set compile options
  compile_opt IDL2

  ; Get ENVI session
  e = ENVI(/CURRENT)

  ; Add the extension to a subfolder
  e.AddExtension, 'Read MTL_json', 'Read_MTL_json', PATH=''
end

; ENVI Extension code. Called when the toolbox item is chosen.
pro Read_MTL_json

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
  
  jsonFile = Dialog_pickfile(/read,FILTER = ['*MTL.json'],$
    TITLE = 'Select a Landsat _MTL.json metadata file')
  ;jsonFile='D:\Experiment\temp\LC08_C2L2\LC08_L2SP_129044_20150104_20200910_02_T1_MTL.json'

  LCC2_Obj = LCC2(jsonFile)
  InputRaster = LCC2_Obj.load('Multispectral')
  outRaster = LCC2_Obj.Scaling()  
  DataColl.add,outRaster
  Layer = View.CreateLayer(outRaster)
  
  InputRaster = LCC2_Obj.load('Temperature')
  outRaster = LCC2_Obj.Scaling()
  DataColl.add,outRaster
  ;Layer = View.CreateLayer(outRaster)
  
  InputRaster = LCC2_Obj.load('QA_Pixel')
  ;InputRaster = LCC2_Obj.load('ST_QA')
  DataColl.add,InputRaster
end
;