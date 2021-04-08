/*
Extract data to calculate K-Factor at each SALI site

Version 2.0 - 07/04/2021 - Added all available TOC methods, method used for OC method and chloride/salinity 
Version 1.1 - 26/10/2020 - Added Lab Method 6B5 (Dumas TC)
Version 1.0 - 11/10/2017 - Orginal script by P.R. Zund

This sql is part of a two step process
Step 1. Run this SQL script "KFactorDataExtraction.sql" to create the data file "KFData.csv"
Step 2. Run the R script "KFactor.R" to create the data file "K.csv"
*/

select distinct
  m.project_code,
  m.site_ID,
  m.obs_no,
  m.horizon_no,
  m.sample_no,
  sn.upper_depth UD,
  sn.lower_depth LD,
  m.lab_meth_code Attribute,
  m.method_used Method,
  m.the_value Value,
  ss.pedality_grade Grade,
  ss.pedality_size Siz,
  ss.pedality_type Type,
  o.permeability Permeability,
  ss.compound_pedality,
  p.objectid,
  c.longitude X, --datum GDA94
  c.latitude Y, --datum GDA94
  (p.objectid||m.site_ID) ID, --Numeric Site ID for marchine learning algorythiums
  EXTRACT(year from o.obs_date)"YEAR" --Year site was described
      
from
  reg_projects p,
  sit_observations o,
  sit_locations c,
  sit_horizons h,
  SIT_SAMPLES sn,
  sit_structures ss,
    (select
    project_code,
    site_id,
    obs_no,
    horizon_no,
    sample_no,
    lab_code,
    lab_meth_code,
    qc_code,
    v the_value,
    m method_used
    
  from
    (select project_code, 
    site_id, 
    obs_no, 
    sample_no, 
    sit_samples.horizon_no, 
    lab_code, 
    lab_meth_code,
    numeric_value, 
    qc_code 
    from sit_lab_results
    left join sit_samples using (project_code, site_id, obs_no, sample_no)) sit_lab_results2
    
  where
    (lab_meth_code like '15%' or lab_meth_code like '18F%' or lab_meth_code like '2Z2_%' or lab_meth_code like '2Z1_%' or lab_meth_code like '2Z1%' or lab_meth_code like '7%' or lab_meth_code like '9%' or lab_meth_code like '6B%'or lab_meth_code in ('3A1','4A1','4B1','5A2', '6A1'))
    and numeric_value != 0 and qc_code != 'Q' and qc_code != 'P'
    model
    return updated rows
    partition by (project_code, site_id, obs_no, horizon_no, sample_no, lab_code)
    dimension by (lab_meth_code)
    measures (numeric_value v, lab_meth_code m)
    keep nav
    unique single reference
    rules upsert automatic order (
    v['CS'] = CEIL(v['2Z2_CS']),
    m['CS'] = m['2Z2_CS'],
    v['FS'] = CEIL(v['2Z2_FS']),
    m['FS'] = m['2Z2_FS'],
    v['Silt'] = CEIL(v['2Z2_Silt']),
    m['Silt'] = m['2Z2_Silt'],
    v['Clay'] = CEIL(v['2Z2_Clay']),
    m['Clay'] = m['2Z2_Clay'],
    v['WB_OC'] = coalesce(v['6A1'], v['6B1'],(v['6B5']*0.935),(v['6B2a']*0.935),(v['6B2']*0.935),(v['6B4b']*0.935),(v['6B4']*0.935)), --6B2a is really 6B2b and 6B5 is really 6B3. SALI TSC plans to change these codes in 2021
    m['WB_OC'] = coalesce(m['6A1'], m['6B1'],m['6B5'],m['6B2a'],m['6B2'],m['6B4b'],m['6B4']), --6B2a is really 6B2b and 6B5 is really 6B3. SALI TSC plans to change these codes in 2021
    v['Chloride'] = v['5A2'],
    m['Chloride'] = v['5A2'],
    v['Salinity'] = v['3A1'],                  
    m['Salinity'] = m['3A1']
    )
  order by 
    project_code, site_id, obs_no, horizon_no, sample_no, lab_meth_code
  ) m

where
  p.project_code = o.project_code --reg_projects to obs table join
  and o.PROJECT_CODE = h.PROJECT_CODE --obs to horizon table join
  and o.SITE_ID = h.SITE_ID --obs to horizon table join
  and o.OBS_NO = h.OBS_NO --obs to horizon table join
  and o.PROJECT_CODE = c.PROJECT_CODE --obs to locations table join
  and o.SITE_ID = c.SITE_ID --obs to locations table join
  and o.OBS_NO = c.OBS_NO --obs to locations table join
  and c.datum = 3 -- lat and long in datum GDA94
  and h.PROJECT_CODE = sn.PROJECT_CODE --horizon to sanples table join
  and h.SITE_ID = sn.SITE_ID --horizon to sanples table join
  and h.OBS_NO = sn.OBS_NO --horizon to sanples table join
  and h.HORIZON_NO = sn.HORIZON_NO --horizon to sanples table join
  and sn.PROJECT_CODE = m.PROJECT_CODE -- samples to lab results table join
  and sn.SITE_ID = m.SITE_ID -- samples to lab results table join
  and sn.OBS_NO = m.OBS_NO -- samples to lab results table join
  and sn.SAMPLE_NO = m.SAMPLE_NO -- samples to lab results table join
  and h.PROJECT_CODE = ss.PROJECT_CODE --horizon to structures table join
  and h.SITE_ID = ss.SITE_ID --horizon to structures table join
  and h.OBS_NO = ss.OBS_NO --horizon to structures table join
  and h.HORIZON_NO = ss.HORIZON_NO --horizon to structures table join
  and ((ss.compound_pedality IS NULL) OR (ss.compound_pedality = 1)) --Structure based on largest ped where there is more than one structure recorded and compound pedality is filled out.
  
  --and c.latitude between -26.98541 and -23.85625 and c.LONGITUDE between 150.28375 and 153.44791 --BMSE modelling area
  and c.latitude between -28.384207 and -27.562490 and c.longitude between 152.422284 and 153.381002 --LASER bounding box modelling area
  
  and sn.lower_depth < .16 -- restrict results to top 15cm of soil
  and m.lab_meth_code in ('Clay', 'CS', 'FS', 'Silt', 'WB_OC', 'Chloride','Salinity')
  
  -- Excluding specfic sites due to data problems in SALI
  and h.project_code NOT LIKE 'CQC' -- data from Project CQC excluded
  and not (h.project_code LIKE 'EIM' and h.Site_ID = 6051) -- data from EIM 6051 excluded
  and not (h.project_code LIKE 'QCS' and h.Site_ID IN (20, 21, 85, 86)) -- data from QCS 20, 21, 85 and 86 excluded
  and not (h.project_code LIKE 'FSE' and h.Site_ID = 126 and sn.sample_no = 3) -- data from FSE 126 (surface bulk) excluded 
  and not (h.project_code LIKE 'ABC' and h.Site_ID = 315) -- Site ABC 315 excluded from all queries because of clay % data inconsistancecy.
  
  --Clay/CS/FS
  and (m.THE_VALUE <= 100) --USE FOR CLAY and CS and FS to elliminate percentage results > 100%
  and not (h.project_code LIKE 'BAN' and h.Site_ID = 95) -- USE FOR CLAY and CS and FS. Site BAN 95 excluded because lab data does not correlate with field description according to LF.
  and not (h.project_code LIKE 'BAMAR' and h.site_ID = 952 and sn.sample_no = 5) -- USE FOR CLAY. Site BAMAR 952 sample 5 excluded as gypsum present in soil solution has flocculated clay =1%
  
  --Silt
  and (m.THE_VALUE <= 100) --USE FOR SILT to elliminate Silt percentage results > 100%
  and not (h.project_code LIKE 'BAN' and h.Site_ID = 95) -- USE FOR SILT. Site BAN 95 excluded because lab data does not correlate with field description according to LF.
  and not (h.project_code LIKE 'MCL' and h.Site_ID = 9052 and sn.sample_no = 31) -- USE FOR SILT. Site MCL 9052 sample 31 excluded because of funny silt value.
  and not (h.project_code LIKE 'BAMAR' and h.Site_ID = 952 and sn.sample_no = 5) -- USE FOR SILT. Site BAMAR 952 sample 5 excluded because of funny silt value.
  and h.project_code NOT LIKE 'MON' -- USE FOR SILT. All MON sites excluded because numeric value is inconsistent with formatted value.
  and not (h.project_code LIKE 'CCL' and h.site_id = 317 and sn.sample_no = 2) -- USE FOR SILT. Sample CCL 317 sample 2 excluded because of funny value.

 --Testing
 --and o.project_code = 'LASER' -- limit for testing code - DO NOT USE
 --and h.site_id = 118  -- limit for testing code - DO NOT USE
  
group by 
  (p.objectid||m.site_ID),
  p.objectid,
  m.project_code,
  m.site_ID,
  m.obs_no,
  m.horizon_no,
  m.sample_no,
  o.obs_date,
  m.the_value,
  m.method_used,
  c.latitude,
  c.longitude,
  sn.upper_depth,
  sn.lower_depth,
  m.lab_meth_code,
  ss.pedality_grade,
  ss.pedality_size,
  ss.pedality_type,
  o.permeability,
  ss.compound_pedality

 order by 
  m.project_code, 
  m.site_id, 
  m.horizon_no,
  m.sample_no
;