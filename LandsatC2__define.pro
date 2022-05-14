
;---------------------------------
;+
; :Description:
;    Describe the procedure.
;     Defining a IDL Object Classe named LandsatC2
;     (定义LandsatC2类，用于根据_MTL.json文件读取Landsat Collection2 Level2数据;)
; :Author: xie
;   Email: xiexj@ecut.edu.cn
;-
Pro LandsatC2__define
  compile_opt IDL2

  struct = {LandsatC2,$
    MTLJsonFile:'',$
    ORIGIN:"Image courtesy of the U.S. Geological Survey",$
    PROCESSING_LEVEL: "L2SP",$
    COLLECTION_NUMBER: 02,$
    SENSOR_ID: "TM",$
    LANDSAT_PRODUCT_ID:'',$
    dataset_name:'Multispectral',$
    Tiff_Names: Ptr_new(0),$
    ST_Tiff_Names: Ptr_new(0),$
    QA_Pixel_Names: Ptr_new(0),$
    InputRaster: Ptr_new(0),$
    Json_Meta: dictionary()}
End
;

;+
; :Description:
;    Describe the procedure.
;     ;; initialization function (初始化函数)
; :Params:
;    LandsatC2::init
; :args:
;   MTLJsonFile : a *_MTL.Json file
;-
Function LandsatC2::init, MTLJsonFile
  compile_opt IDL2

  If N_elements(MTLJsonFile) Gt 0 Then Begin
    self.MTLJsonFile = MTLJsonFile
  Endif else $
    MESSAGE, /IOERROR, "MTL.Json file is required for this function."

  ;;Load metadata information from MTL.Json file and initialize (加载元数据信息并初始化)
  dict = JSON_PARSE(MTLJsonFile,/DICTIONARY)
  product_contents = dict.landsat_metadata_file.product_contents
  self.landsat_product_id = product_contents.landsat_product_id
  self.processing_level = product_contents.processing_level  
  image_attributes = dict.landsat_metadata_file.image_attributes  
  self.SENSOR_ID = image_attributes.sensor_id

  case self.SENSOR_ID of 
;    'MSS': begin
;      MS_BandNum = strtrim(string(indgen(4)+4),2)
;      Band_Names = ['Green','Red', 'NIR1', 'NIR2']
;      Wavelengths = [0.55,0.65,0.75,0.95]
;      end
    'TM': begin
        MS_BandNum = strtrim(string([indgen(5)+1,7]),2)
        ST_BandNum = ['6']
        Band_Names = ['Blue','Green','Red','NIR','SWIR 1','SWIR 2']
        Wavelengths = [0.485,0.565,0.655,0.865,1.655,2.205]
      end
    'ETM':begin
        MS_BandNum = strtrim(string([indgen(5)+1,7]),2)
        ST_BandNum = ['6']
        Band_Names = ['Blue','Green','Red','NIR','SWIR 1','SWIR 2']
        Wavelengths = [0.485,0.565,0.655,0.865,1.655,2.205]
      end
    'OLI_TIRS': begin
        MS_BandNum = strtrim(string(indgen(7)+1),2)
        ST_BandNum = ['10','11']
        Band_Names = ['Coastal aerosol','Blue',$
          'Green','Red', 'NIR', 'SWIR 1','SWIR 2']
        Wavelengths = [0.4430,0.4826,0.5613,0.6546,0.8646,1.6090,2.2010]
      end
    ELSE: print,'ERROR: MSS data is not supported' 
  endcase  
  
  level1_parameters = dict.landsat_metadata_file.level1_radiometric_rescaling  
  keys = ['Band_Names','Wavelengths','Radiance_Gains',$
    'Radiance_Offsets','Reflectance_Gains','Reflectance_Offsets',$
    'Cloud_Cover','Sun_Azimuth','Sun_Elevation','Earth_Sun_Distance',$
    'Spacecraft','Sensor_Type','Date_Acquired','Scene_Center_Time']

  values = LIST(Band_Names, Wavelengths,$
    level1_parameters['RADIANCE_MULT_BAND_' + MS_BandNum].values(),$
    level1_parameters['RADIANCE_ADD_BAND_' + MS_BandNum].values(),$
    level1_parameters['REFLECTANCE_MULT_BAND_' + MS_BandNum].values(),$
    level1_parameters['REFLECTANCE_ADD_BAND_' + MS_BandNum].values(),$
    image_attributes.cloud_cover,image_attributes.sun_azimuth,$
    image_attributes.sun_elevation,image_attributes.earth_sun_distance,$
    image_attributes.spacecraft_id,image_attributes.sensor_id,$
    image_attributes.date_acquired,image_attributes.scene_center_time)

  MsDict = DICTIONARY(keys, values)
  
  ;; 根据不同级别的输入数据，分别获取影像波段文件及其Scaling参数 
  self.Tiff_Names = Ptr_new(0) 
  self.ST_Tiff_Names = Ptr_new(0)
  self.QA_Pixel_Names = Ptr_new(0)
 
  if self.processing_level eq 'L2SP' then begin
    ; 输入数据为'L2SP'级别时
    *self.Tiff_Names = self.landsat_product_id + '_SR_B'+ MS_BandNum +'.TIF'
    *self.ST_Tiff_Names = self.landsat_product_id + '_ST_B'+ ST_BandNum[0] +'.TIF'
    *self.QA_Pixel_Names = self.landsat_product_id + ['_ST_QA', '_QA_PIXEL']+'.TIF'
    
    level2_SR_parameters = dict.landsat_metadata_file.level2_surface_reflectance_parameters
    SR_MULT = level2_SR_parameters['REFLECTANCE_MULT_BAND_' + MS_BandNum].values()
    SR_ADD = level2_SR_parameters['REFLECTANCE_ADD_BAND_' + MS_BandNum].values()
    keys = ['SR_MULT','SR_ADD','ST_reScaling']
    values = LIST(SR_MULT,SR_ADD,[0.00341802,149.0-273])    
  endif else begin
    if self.processing_level eq 'L1TP' then begin
      ; 输入数据为'L1TP'级别时
      *self.Tiff_Names = self.landsat_product_id + '_B'+ MS_BandNum +'.TIF'
      *self.ST_Tiff_Names = self.landsat_product_id + '_B'+ ST_BandNum +'.TIF' 
      *self.QA_Pixel_Names = self.landsat_product_id + ['_QA_RADSAT', '_QA_PIXEL']+'.TIF'

      Rad_TC_MULT = level1_parameters['RADIANCE_MULT_BAND_' + ST_BandNum].values()
      Rad_TC_ADD = level1_parameters['RADIANCE_ADD_BAND_' + ST_BandNum].values()     
      level1_TC = dict.landsat_metadata_file.level1_thermal_constants      
      K1_constant = level1_TC['K1_CONSTANT_BAND_' + ST_BandNum].values()
      K2_constant = level1_TC['K2_CONSTANT_BAND_' + ST_BandNum].values()      
      keys = ['Rad_TC_MULT','Rad_TC_ADD','TC_MULT','TC_ADD']
      values = LIST(Rad_TC_MULT,Rad_TC_ADD,K1_constant,K2_constant)  
    endif else PRINT, 'Error opening'
  endelse 
  self.Json_Meta = MsDict + DICTIONARY(keys, values)
  
  self.InputRaster = Ptr_new(0)
 
  Return,1b
End
;

;;---------------------------------
;+
; :Description:
;    Describe the procedure.
;     Load image data (加载影像数据)
; :Params:
;    LandsatC2::Load
; :args:
;   dataset_name : Specify the open image data variable
;   
;-
Function LandsatC2::Load,dataset_name
  compile_opt IDL2

  ;;加载指定数据集合
  If N_elements(dataset_name) Gt 0 Then Begin
    self.dataset_name = dataset_name
  Endif Else self.dataset_name = 'Multispectral'

  e = envi(/current)
  FileDirName = File_dirname(self.MTLJsonFile)
  DataColl = e.Data

  if self.dataset_name eq 'Multispectral' then begin
    Tiff_Names = *self.Tiff_Names    
    InputRaster = load_tiff(Tiff_Names,FileDirName)
    
    ; Edit the ENVI header (设置多光谱文件属性)
    Metadata = InputRaster.Metadata
    Metadata.AddItem, 'wavelength units','micrometers'
    Metadata.AddItem, 'wavelength',self.Json_Meta['Wavelengths']
    Metadata.updateitem, 'band names',self.Json_Meta['Band_Names']
    Metadata.Additem, 'Cloud Cover',self.Json_Meta['Cloud_Cover']
    Metadata.Additem, 'Sun Azimuth', self.Json_Meta['Sun_Azimuth']
    Metadata.Additem, 'Sun Elevation', self.Json_Meta['Sun_Elevation']
    Metadata.Additem, 'Earth Sun Distance', self.Json_Meta['Earth_Sun_Distance']
    Metadata.Additem, 'Spacecraft', self.Json_Meta['Spacecraft']
    Metadata.Additem, 'Sensor Type', self.Json_Meta['Sensor_Type']
    Metadata.Additem, 'Date Acquired', self.Json_Meta['Date_Acquired']
    Metadata.Additem, 'Scene Center Time', self.Json_Meta['Scene_Center_Time']

  endif else begin
    ;; Loading surface temperature images (加载地表温度影像)
    if self.dataset_name eq 'Temperature' then $
      Tiff_Names = *self.ST_Tiff_Names
    if self.dataset_name eq 'QA_Pixel' then $
      Tiff_Names = *self.QA_Pixel_Names
    
    InputRaster = load_tiff(Tiff_Names,FileDirName)
    Metadata = InputRaster.Metadata
    Metadata.updateitem, 'band names',Tiff_Names
  endelse

  *self.InputRaster = InputRaster
  return,*self.InputRaster
end
;

;--------------------------------------
;+
; :Description:
;    Describe the procedure.
;
; :Params:
;    Tiff_Names ;需要导入的Tiff图像文件名(数组)
;    FileDirName ;需要导入的Tiff图像文件所在目录
;
;-
function load_tiff,Tiff_Names,FileDirName
  compile_opt IDL2

  e = envi(/current)  
  DataColl = e.Data

  ;;----------  Load Imagery (加载影像) ------------
  TiffRasters = !null
  nb = N_ELEMENTS(Tiff_Names)
  for i=0,nb-1 do begin
    TiffFileName = FileDirName + Path_sep()+ Tiff_Names[i]
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

  return,InputRaster
end
;

;---------------------------------

;--------------------------------------
;+
; :Description:
;    Describe the procedure.
;     Restore the image to the real surface reflectance (0-1) or surface temperature (°C)
;       (scaling:将影像缩放还原为真实地表反射率(0-1)或地表温度(℃))
; :Params:
;    LandsatC2::Scaling
; :args:
;   outFile : a output raster file
;-
;;
Function LandsatC2::Scaling,outFile=outFile
  compile_opt IDL2
  
  if self.processing_level eq 'L2SP' then begin
    ; Specify the gains and offsets
    if self.dataset_name eq 'Multispectral' then begin
      Gains = self.Json_Meta['SR_MULT'].ToArray(TYPE=4)
      Offsets = self.Json_Meta['SR_ADD'].ToArray(TYPE=4)
    endif

    if self.dataset_name eq 'Temperature' then begin
      scale = self.Json_Meta['ST_reScaling']
      Gains = [scale[0]]
      Offsets = [scale[1]]
    endif
    
  endif else if self.processing_level eq 'L1TP' then begin
    ; Specify the gains and offsets
    if self.dataset_name eq 'Multispectral' then begin
      Gains = self.Json_Meta['Radiance_Gains'].ToArray(TYPE=4)
      Offsets = self.Json_Meta['Radiance_Offsets'].ToArray(TYPE=4)
    endif

    if self.dataset_name eq 'Temperature' then begin
      Gains = self.Json_Meta['Rad_TC_MULT'].ToArray(TYPE=4)
      Offsets = self.Json_Meta['Rad_TC_ADD'].ToArray(TYPE=4)
    endif
  endif
  
  outRaster = ENVIGainOffsetRaster(*self.InputRaster, Gains, Offsets)
  
  If N_elements(outFile) Gt 0 Then Begin
    outRaster.Export, outFile, 'ENVI'
  Endif
  return,outRaster
end

Pro LandsatC2::Cleanup
  Obj_destroy, self
end
