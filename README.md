# Read_MTL_json
A small plug-in developed based on ENVI5.3/IDL8.5 to open Landsat Collection2 Level 2 data released by USGS

# 工具中文说明
背景：临近毕业，有不少同学咨询Landsat Collection2 Level 2 数据在ENVI中打不开的问题，为方便大家，编写并分享此工具。

下载：https://github.com/xiexjrs/ENVI_Read_MTL_json/blob/main/read_mtl_json.sav

## 工具介绍	
1. 功能：
	通过ENVI打开USGS发布的Landsat Collection2 Level 2 数据（已经过定标和大气校正）
2. 测试/适用平台：
	在ENVI8.3/IDL8.5上测试可用，理论上适用于ENVI8.3及以上版本
3. 测试/数据：
	在USGS/aliyun AI Earth等平台下载的Landsat Collection2 Level 2数据（如LC08_L2SP_129044_20150104_20200910_02_T1.tar）

## 工具安装与使用
1. 安装：
	将压缩包中的read_mtl_json.sav文件拷贝到ENVI安装目录下extensions文件夹中即可。
2. 使用：
	拷贝完成后，重启ENVI，双击右下角Read MTL_json;
	在弹出对话框中，选择数据目录下的_MTL.json文件（如LC08_L2SP_129044_20150104_20200910_02_T1_MTL.json）
	如果没报错，工具自动加载缩放后的地表反射率影像集、地表温度和QA_Pixel质量影像
3. 免责声明：
	本工具基于ENVI8.3/IDL8.5二次开发，不能保证与所有的软硬件系统完全兼容，在使用过程中遇到报错，可联系xiexj@ecut.edu.cn。
	对任何原因在使用此工具时可能对用户自己或他人造成的任何形式的损失和伤害不承担责任，如有侵权，可联系删除。
