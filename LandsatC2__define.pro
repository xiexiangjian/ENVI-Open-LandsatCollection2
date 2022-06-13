
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
    InputRasters: Ptr_new(0),$
    Json_Meta: ORDEREDHASH()}
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
  OrderHash = JSON_PARSE(MTLJsonFile)
  product_contents = OrderHash['LANDSAT_METADATA_FILE','PRODUCT_CONTENTS']
  self.landsat_product_id = product_contents['LANDSAT_PRODUCT_ID']
  self.processing_level = product_contents['PROCESSING_LEVEL']
  image_attributes = OrderHash['LANDSAT_METADATA_FILE','IMAGE_ATTRIBUTES']
  SELF.SENSOR_ID = image_attributes['SENSOR_ID']

  case self.SENSOR_ID of
    ;    'MSS': begin
    ;      MS_BandNum = strtrim(string(indgen(4)+4),2)
    ;      Band_Names = ['Green','Red', 'NIR1', 'NIR2']
    ;      Wavelengths = [0.55,0.65,0.75,0.95]
    ;      end
    'TM': begin
      BandNum = indgen(7)
      MS_BandNum = [indgen(5),6]
      ST_BandNum = [5]
      Band_Names = ['Blue','Green','Red','NIR','SWIR 1','TIR','SWIR 2']
      Wavelengths = [0.485,0.565,0.655,0.865,1.655,11.435,2.205]
    end
    'ETM':begin
      MS_BandNum = [indgen(5),6]
      ST_BandNum = [5]
      BandNum = indgen(8)
      Band_Names = ['Blue','Green','Red','NIR','SWIR 1','TIR','SWIR 2','Panchromatic']
      Wavelengths = [0.485,0.565,0.655,0.865,1.655,11.435,2.205,0.750]
    end
    'OLI_TIRS': begin
      MS_BandNum = indgen(7)
      ST_BandNum = [9,10]
      BandNum = indgen(11)
      Band_Names = ['Coastal aerosol','Blue','Green','Red', 'NIR',$
        'SWIR 1','SWIR 2','Panchromatic','Cirrus','TIR1','TIR2']
      Wavelengths = [0.4430,0.4826,0.5613,0.6546,0.8646,1.6090,2.2010,0.5917,1.373,10.9,12.0]
    end
    ELSE: print,'ERROR: MSS data is not supported'
  endcase

  keys = ['Cloud_Cover','Sun_Azimuth','Sun_Elevation','Earth_Sun_Distance',$
    'Spacecraft','Sensor_Type','Date_Acquired','Scene_Center_Time']
  values = LIST(image_attributes['CLOUD_COVER'],image_attributes['SUN_AZIMUTH'],$
    image_attributes['SUN_ELEVATION'],image_attributes['EARTH_SUN_DISTANCE'],$
    image_attributes['SPACECRAFT_ID'],image_attributes['SENSOR_ID'],$
    image_attributes['DATE_ACQUIRED'],image_attributes['SCENE_CENTER_TIME'])

  self.Json_Meta = ORDEREDHASH(keys, values)

  BandNum_str = strtrim(string(BandNum+1),2)
  MS_BandNum_str = strtrim(string(MS_BandNum+1),2)
  ST_BandNum_str = strtrim(string(ST_BandNum+1),2)

  ;; 根据不同级别的输入数据，分别获取影像波段文件及其Scaling参数
  if self.processing_level eq 'L2SP' then begin
    ; 输入数据为'L2SP'级别时
    keys = ['Band_Names','Wavelengths','Radiance_Gains','Radiance_Offsets',$
      'Tiff_Names','MS_Bands','ST_Bands']

    ST_BandNum = ST_BandNum[0]
    BandNum = [MS_BandNum,ST_BandNum]
    Band_Names = Band_Names[BandNum]
    Wavelengths = Wavelengths[BandNum]

    level2_SR_parameters = OrderHash['LANDSAT_METADATA_FILE','LEVEL2_SURFACE_REFLECTANCE_PARAMETERS']
    SR_MULT_OrderHash = level2_SR_parameters['REFLECTANCE_MULT_BAND_' + MS_BandNum_str]
    SR_MULT = (SR_MULT_OrderHash.values()).ToArray(TYPE=4)
    SR_ADD_OrderHash = level2_SR_parameters['REFLECTANCE_ADD_BAND_' + MS_BandNum_str]
    SR_ADD = (SR_ADD_OrderHash.values()).ToArray(TYPE=4)
    level2_Rad_Mult = [SR_MULT,0.00341802]
    level2_Rad_Add = [SR_ADD,149.0-273]

    ST_BandNum_str = 'ST_B'+ strtrim(string(ST_BandNum+1),2)
    Tiff_Names = (product_contents['FILE_NAME_BAND_' + $
      [MS_BandNum_str,ST_BandNum_str]].values()).ToArray()

    MS_BandNum = indgen(N_ELEMENTS(MS_BandNum))
    ST_BandNum = N_ELEMENTS(Tiff_Names)-1

    values = LIST(Band_Names, Wavelengths,level2_Rad_Mult,$
      level2_Rad_Add,Tiff_Names,MS_BandNum,ST_BandNum)

  endif else if self.processing_level eq 'L1TP' then begin
    ; 输入数据为'L1TP'级别时
    keys = ['Band_Names','Wavelengths','Radiance_Gains','Radiance_Offsets',$
      'Tiff_Names','MS_Bands','ST_Bands','K1_constant','K2_constant']

    level1_Rad = OrderHash['LANDSAT_METADATA_FILE','LEVEL1_RADIOMETRIC_RESCALING']
    level1_TC = OrderHash['LANDSAT_METADATA_FILE','LEVEL1_THERMAL_CONSTANTS']
    level1_Rad_Mult = (level1_Rad['RADIANCE_MULT_BAND_' + BandNum_str].values()).ToArray(TYPE=4)
    level1_Rad_Add = (level1_Rad['RADIANCE_ADD_BAND_' + BandNum_str].values()).ToArray(TYPE=4)
    level1_TC_K1 = (level1_TC['K1_CONSTANT_BAND_' + ST_BandNum_str].values()).ToArray(TYPE=4)
    level1_TC_K2 = (level1_TC['K2_CONSTANT_BAND_' + ST_BandNum_str].values()).ToArray(TYPE=4)
    Tiff_Names =  (product_contents['FILE_NAME_BAND_'+ BandNum_str].values()).ToArray()

    values = LIST(Band_Names, Wavelengths,level1_Rad_Mult,level1_Rad_Add,$
      Tiff_Names,MS_BandNum,ST_BandNum,level1_TC_K1,level1_TC_K2)

  endif else begin
    print,'请选择Landsat Collection 2 L1TP或 L2SP 产品数据' 
    Return,0
  endelse

  self.Json_Meta = self.Json_Meta + ORDEREDHASH(keys, values)

  self.InputRasters = Ptr_new(0)

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
Function LandsatC2::Load,MsRaster = MsRaster,TirRaster = TirRaster,$
  PanRaster = PanRaster,QA_Pixel_Raster = QA_Pixel_Raster
  compile_opt IDL2

  ;  ;;加载指定数据集合
  ;  If N_elements(dataset_name) Gt 0 Then Begin
  ;    self.dataset_name = dataset_name
  ;  Endif Else self.dataset_name = 'Multispectral'

  e = envi(/current)
  FileDirName = File_dirname(self.MTLJsonFile)
  DataColl = e.Data
  OutputRasters = !null

  ;;读取多光谱数据
  Bands_num = self.Json_Meta['MS_Bands']
  Tiff_Names = (self.Json_Meta['Tiff_Names'])[Bands_num]
  MsRaster = load_tiff(Tiff_Names,FileDirName)
  ; Edit the ENVI header (设置头文件)
  Metadata = MsRaster.Metadata
  Metadata.AddItem, 'wavelength units','micrometers'
  Metadata.updateitem, 'band names',(self.Json_Meta['Band_Names'])[Bands_num]
  Metadata.Additem, 'wavelength',(self.Json_Meta['Wavelengths'])[Bands_num]
  Metadata.Additem, 'data gain values',(self.Json_Meta['Radiance_Gains'])[Bands_num]
  Metadata.Additem, 'data offset values',(self.Json_Meta['Radiance_Offsets'])[Bands_num]
  Metadata.Additem, 'Cloud Cover',self.Json_Meta['Cloud_Cover']
  Metadata.Additem, 'Sun Azimuth', self.Json_Meta['Sun_Azimuth']
  Metadata.Additem, 'Sun Elevation', self.Json_Meta['Sun_Elevation']
  Metadata.Additem, 'Earth Sun Distance', self.Json_Meta['Earth_Sun_Distance']
  Metadata.Additem, 'Spacecraft', self.Json_Meta['Spacecraft']
  Metadata.Additem, 'Sensor Type', self.Json_Meta['Sensor_Type']
  Metadata.Additem, 'Date Acquired', self.Json_Meta['Date_Acquired']
  Metadata.Additem, 'Scene Center Time', self.Json_Meta['Scene_Center_Time']

  ;;读取热红外数据
  Bands_num = self.Json_Meta['ST_Bands']
  Tiff_Names = (self.Json_Meta['Tiff_Names'])[Bands_num]
  TirRaster = load_tiff(Tiff_Names,FileDirName)
  ; Edit the ENVI header (设置头文件)
  Metadata = TirRaster.Metadata
  Metadata.AddItem, 'wavelength units','micrometers'
  Metadata.updateitem, 'band names',(self.Json_Meta['Band_Names'])[Bands_num]
  Metadata.Additem, 'wavelength',(self.Json_Meta['Wavelengths'])[Bands_num]
  Metadata.Additem, 'data gain values',(self.Json_Meta['Radiance_Gains'])[Bands_num]
  Metadata.Additem, 'data offset values',(self.Json_Meta['Radiance_Offsets'])[Bands_num]

  ;;读取Qa_Pixel数据
  Tiff_Name = self.landsat_product_id + ['_QA_PIXEL']+'.TIF'
  TiffFileName = FileDirName + Path_sep()+ Tiff_Name
  QA_Pixel_Raster = e.OpenRaster(TiffFileName)

  OutputRasters = [MsRaster,TirRaster,QA_Pixel_Raster]
  ;;读取全色影像数据
  if SELF.SENSOR_ID ne 'TM' and self.processing_level eq 'L1TP' then begin
    Bands_num = 7
    Tiff_Names = (self.Json_Meta['Tiff_Names'])[Bands_num]
    PanRaster = load_tiff(Tiff_Names,FileDirName)
    ; Edit the ENVI header (设置头文件)
    Metadata = PanRaster.Metadata
    Metadata.AddItem, 'wavelength units','micrometers'
    Metadata.updateitem, 'band names',(self.Json_Meta['Band_Names'])[Bands_num]
    Metadata.Additem, 'wavelength',(self.Json_Meta['Wavelengths'])[Bands_num]
    Metadata.Additem, 'data gain values',(self.Json_Meta['Radiance_Gains'])[Bands_num]
    Metadata.Additem, 'data offset values',(self.Json_Meta['Radiance_Offsets'])[Bands_num]

    OutputRasters = [OutputRasters,PanRaster]
  endif

  ;DataColl.add,OutputRasters

  *self.InputRasters = OutputRasters

  return,*self.InputRasters
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
  ; 设置投影
  SpatialRef=TiffRasters[0].SPATIALREF
  InputRaster = ENVIMetaspectralRaster(TiffRasters,SPATIALREF=SPATIALREF)
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
Function LandsatC2::Scaling, outTirRaster = outTirRaster,$
  outPanRaster = outPanRaster

  compile_opt IDL2
  e = envi(/current)

  Gains = [(self.Json_Meta['Radiance_Gains'])[self.Json_Meta['MS_Bands']]]
  Offsets = [(self.Json_Meta['Radiance_Offsets'])[self.Json_Meta['MS_Bands']]]
  outMsRaster = ENVIGainOffsetRaster((*self.InputRasters)[0], Gains, Offsets)

  Gains = [(self.Json_Meta['Radiance_Gains'])[self.Json_Meta['ST_Bands']]]
  Offsets = [(self.Json_Meta['Radiance_Offsets'])[self.Json_Meta['ST_Bands']]]
  outTirRaster = ENVIGainOffsetRaster((*self.InputRasters)[1], Gains, Offsets)

  ;;读取全色影像数据
  if SELF.SENSOR_ID ne 'TM' and self.processing_level eq 'L1TP' then begin
    Gains = [(self.Json_Meta['Radiance_Gains'])[7]]
    Offsets = [(self.Json_Meta['Radiance_Offsets'])[7]]
    outPanRaster = ENVIGainOffsetRaster((*self.InputRasters)[2], Gains, Offsets)
  endif

  return,outMsRaster
end

Pro LandsatC2::Cleanup
  Obj_destroy, self
end
