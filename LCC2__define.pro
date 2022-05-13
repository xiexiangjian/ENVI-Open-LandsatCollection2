;+
; :Description:
;    Describe the procedure.
;     ;; initialization function (初始化函数)
; :Params:
;    LCC2::init
; :args:
;   MTLJsonFile : a *_MTL.Json file
;-
Function LCC2::init,MTLJsonFile
  compile_opt IDL2

  If N_elements(MTLJsonFile) Gt 0 Then Begin
    self.MTLJsonFile = MTLJsonFile
  Endif else $
    MESSAGE, /IOERROR, "MTL.Json file is required for this function."
  
  ;;Load metadata information from MTL.Json file and initialize (加载元数据信息并初始化)
  dict = JSON_PARSE(MTLJsonFile,/DICTIONARY)
  product_contents = dict.landsat_metadata_file.product_contents
  self.landsat_product_id = product_contents.landsat_product_id

  IMAGE_ATTRIBUTES = dict.landsat_metadata_file.IMAGE_ATTRIBUTES
  self.SPACECRAFT_ID = IMAGE_ATTRIBUTES.SPACECRAFT_ID
  self.SENSOR_ID = IMAGE_ATTRIBUTES.SENSOR_ID
  self.DATE_ACQUIRED = IMAGE_ATTRIBUTES.DATE_ACQUIRED
  self.SCENE_CENTER_TIME = IMAGE_ATTRIBUTES.SCENE_CENTER_TIME
  self.CLOUD_COVER = IMAGE_ATTRIBUTES.CLOUD_COVER
  self.CLOUD_COVER_LAND = IMAGE_ATTRIBUTES.CLOUD_COVER_LAND
  self.SUN_AZIMUTH = IMAGE_ATTRIBUTES.SUN_AZIMUTH
  self.SUN_ELEVATION = IMAGE_ATTRIBUTES.SUN_ELEVATION
  self.EARTH_SUN_DISTANCE = IMAGE_ATTRIBUTES.EARTH_SUN_DISTANCE

  self.Multispec_Meta.RasterName = 'Multispectral'
  self.Multispec_Meta.wavelength_units = 'micrometers'
  self.Multispec_Meta.wavelength = [0.4430,0.4826,0.5613,$
    0.6546,0.8646,1.6090,2.2010]
  self.Multispec_Meta.bandnames = ['Coastal aerosol','Blue',$
    'Green','Red', 'NIR', 'SWIR 1','SWIR 2']
  self.Multispec_Meta.nbands = 7
  self.Multispec_Meta.REFLECTANCE_MULT = 2.75e-05
  self.Multispec_Meta.REFLECTANCE_ADD = -0.2

  self.TEMPERATURE_Meta.RasterName = 'Temperature'
  self.TEMPERATURE_Meta.bandnames = 'Surface temperature'
  self.TEMPERATURE_Meta.TEMPERATURE_MULT = 0.00341802
  self.TEMPERATURE_Meta.TEMPERATURE_ADD = 149.0-273

  self.InputRaster = Ptr_new(0)
  Return,1b
End
;

;---------------------------------
;+
; :Description:
;    Describe the procedure.
;     Load image data (加载影像数据)
; :Params:
;    LCC2::Load
; :args:
;   dataset_name : Specify the open image data variable
;   
;-
Function LCC2::Load,dataset_name
  compile_opt IDL2

  ;;加载指定数据集合
  If N_elements(dataset_name) Gt 0 Then Begin
    self.dataset_name = dataset_name
  Endif Else self.dataset_name = 'Multispectral'

  e = envi(/current)
  FileDirName = File_dirname(self.MTLJsonFile)
  DataColl = e.Data

  ;; Load Multispectral Imagery (加载多光谱影像)
  TiffRasters = !null
  if self.dataset_name eq 'Multispectral' then begin
    for i=0,6 do begin
      TiffFileName = FileDirName + Path_sep()$
        + self.landsat_product_id $
        + '_SR_B'+ strtrim(string(i+1),2)+ '.TIF'
      TiffRasters = [TiffRasters,e.OpenRaster(TiffFileName)]
    endfor

  ;;----------  LayerStacking (图层叠加) ------------ 
    ; 建立地理格网
    grid = ENVIGridDefinition(TiffRasters[0])
    SpatialRef=TiffRasters[0].SPATIALREF
    InputRaster = ENVIMetaspectralRaster(TiffRasters,SPATIALREF=SPATIALREF)  
    MSS_SpatialGridRaster = ENVISpatialGridRaster(InputRaster, $
      GRID_DEFINITION=Grid)
    DataColl.remove,TiffRasters

    ; Edit the ENVI header (设置多光谱文件属性)
    Metadata = InputRaster.Metadata
    Metadata.AddItem, 'wavelength units', $
      self.Multispec_Meta.wavelength_units
    Metadata.AddItem, 'wavelength', $
      self.Multispec_Meta.wavelength
    Metadata.updateitem, 'band names', $
      self.Multispec_Meta.bandnames
    Metadata.Additem, 'date_acquired',self.DATE_ACQUIRED
    Metadata.Additem, 'scene_center_time', self.SCENE_CENTER_TIME
  endif

  ;; Loading surface temperature images (加载地表温度影像)
  if self.dataset_name eq 'Temperature' then begin
    TiffFileName = FileDirName + Path_sep()$
      + self.landsat_product_id $
      + '_ST_B10.TIF'
    InputRaster = e.OpenRaster(TiffFileName)
    Metadata = InputRaster.Metadata
    Metadata.updateitem, 'band names', $
      self.TEMPERATURE_Meta.bandnames
  endif

  ;; Load quality images (加载QA质量影像)
  if self.dataset_name eq 'ST_QA' then begin
    TiffFileName = FileDirName + Path_sep()$
      + self.landsat_product_id $
      + '_ST_QA.TIF'
    InputRaster = e.OpenRaster(TiffFileName)    
  endif
  if self.dataset_name eq 'QA_Pixel' then begin
    TiffFileName = FileDirName + Path_sep()$
      + self.landsat_product_id $
      + '_QA_PIXEL.TIF'
    InputRaster = e.OpenRaster(TiffFileName)
  endif

  *self.InputRaster = InputRaster 
  return,InputRaster 
end
;

;---------------------------------
;+
; :Description:
;    Describe the procedure.
;     Restore the image to the real surface reflectance (0-1) or surface temperature (°C)
;       (scaling:将影像缩放还原为真实地表反射率(0-1)或地表温度(℃))
; :Params:
;    LCC2::Scaling
; :args:
;   outFile : a output raster file
;-
;;
Function LCC2::Scaling,outFile=outFile
  compile_opt IDL2
  ; Specify the gains and offsets
  if self.dataset_name eq 'Multispectral' then begin
    Gains = make_array(7,value = self.Multispec_Meta.REFLECTANCE_MULT)
    Offsets =  make_array(7,value = self.Multispec_Meta.REFLECTANCE_ADD)
    outRaster = ENVIGainOffsetRaster(*self.InputRaster, Gains, Offsets)
  endif

  if self.dataset_name eq 'Temperature' then begin
    Gains = [self.TEMPERATURE_Meta.TEMPERATURE_MULT]
    Offsets =  [self.TEMPERATURE_Meta.TEMPERATURE_ADD]
    outRaster = ENVIGainOffsetRaster(*self.InputRaster, Gains, Offsets)
  endif

  If N_elements(outFile) Gt 0 Then Begin
    outRaster.Export, outFile, 'ENVI'
  Endif
  return,outRaster
end

Pro LCC2::Cleanup
  Obj_destroy, self
end

;---------------------------------
;+
; :Description:
;    Describe the procedure.
;     Defining a IDL Object Classe named LCC2 
;     (定义LCC2类，用于根据_MTL.json文件读取Landsat Collection2 Level2数据;)
; :Author: xie
;   Email: xiexj@ecut.edu.cn
;-
Pro LCC2__define
  compile_opt IDL2

  struct = {LCC2,$
    MTLJsonFile:'',$
    ORIGIN:"Image courtesy of the U.S. Geological Survey",$
    PROCESSING_LEVEL: "L2SP",$
    COLLECTION_NUMBER: 02,$
    COLLECTION_CATEGORY: "T1",$
    LANDSAT_PRODUCT_ID:'',$
    SPACECRAFT_ID: "LANDSAT_8",$
    SENSOR_ID: "OLI_TIRS",$
    DATE_ACQUIRED: '',$
    SCENE_CENTER_TIME:'',$
    CLOUD_COVER:0.0 ,$
    CLOUD_COVER_LAND: 0.0,$
    SUN_AZIMUTH: 90.0,$
    SUN_ELEVATION: 38.0,$
    EARTH_SUN_DISTANCE: 0.9832774,$
    dataset_name:'Multispectral',$
    InputRaster: Ptr_new(0),$
    Multispec_Meta: {Multispec_Meta,$
      RasterName:'Multispectral',$
      wavelength_units: 'micrometers',$
      wavelength: [0.4430,0.4826,0.5613,$
      0.6546,0.8646,1.6090,2.2010], $
      bandnames:['Coastal aerosol','Blue', 'Green', $
      'Red', 'NIR', 'SWIR 1','SWIR 2'],$
      nbands: 7,$
      REFLECTANCE_MULT: 2.75e-05 ,$
      REFLECTANCE_ADD: -0.2 },$
    TEMPERATURE_Meta: {Temperature_Meta,$
      RasterName:'Temperature',$
      bandnames: 'Surface temperature',$
      TEMPERATURE_MULT: 0.00341802,$
      TEMPERATURE_ADD: 149.0}$
}
End
;