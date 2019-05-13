/*
Extract data to calculate K-Factor at each SALI site that has the available data and format for Cubist.
Version 1.0 - 11/10/2017 - Orginal script

This sql is part of a two step process
Step 1. Run this SQL script "KFactorDataExtraction.sql" to create the data file "KFData.csv"
Step 2. Run the R script "KFactor.R" to create the data file "K.csv"
*/

select distinct
  (p.objectid||m.site_ID) ID, --Single site ID for spline input
  (sn.upper_depth*100)UD, -- Upper depth in cm for spline tool
  (sn.lower_depth*100)LD, -- Lower depth in cm for spline tool
  m.lab_meth_code Attribute,
  --CEIL(m.the_value) Value, --USE FOR Clay, Silt, FS, CS AND ESP. Round result UP to nearest whole integer.
  m.the_value Value,
  ss.pedality_grade Grade,
  ss.pedality_size Siz,
  ss.pedality_type Type,
  o.permeability Permeability,
  ss.compound_pedality,
  p.objectid,
  m.project_code,
  m.site_ID,
  m.obs_no,
  m.horizon_no,
  m.sample_no,
  EXTRACT(year from o.obs_date)"YEAR", --Year site was described
  c.latitude, --datum GDA94
  c.longitude, --datum GDA94
  c.zone,
  c.easting,
  c.northing
      
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
    sit_lab_results
      
  where
    (lab_meth_code like '15%' or lab_meth_code like '18F%' or lab_meth_code like '2Z2_%' or lab_meth_code like '2Z1_%' or lab_meth_code like '2Z1%' or lab_meth_code like '7A%' or lab_meth_code like '6B%'or lab_meth_code in ('3A1','4A1', '3A1', '5A2', '6A1'))
    and numeric_value != 0 and qc_code != 'Q' and qc_code != 'P'
    model
    return updated rows
    partition by (project_code, site_id, obs_no, horizon_no, sample_no, lab_code)
    dimension by (lab_meth_code)
    measures (numeric_value v, lab_meth_code m)
    keep nav
    unique single reference
    rules upsert automatic order (
      v['Cat_Ca'] = (case
                      when v['4A1'] < 7.3 and v['3A1'] > 0.3 then
                        coalesce(v['15A2_Ca'], v['15A1_Ca'], v['15F1_Ca'], v['15C1_Ca'], v['18F1_Ca']/200, v['15A1_Ca_MQ02'], v['15C1_Ca_MQ01'])
                      when v['4A1'] >= 7.3 then
                        coalesce(v['15C1_Ca'], v['15F1_Ca'], v['15A1_Ca'], v['15C1_Ca_MQ01'])
                      else
                        coalesce(v['15A1_Ca'], v['15A2_Ca'], v['15F1_Ca'], v['15C1_Ca'], v['15D3_Ca'], v['18F1_Ca']/200, v['15A1_Ca_MQ02'], v['15C1_Ca_MQ01'])
                    end),
      v['Cat_Mg'] = (case
                      when v['4A1'] < 7.3 and v['3A1'] > 0.3 then
                        coalesce(v['15A2_Mg'], v['15A1_Mg'], v['15F1_Mg'], v['15C1_Mg'], v['18F1_Mg']/120, v['15A1_Mg_MQ02'], v['15C1_Mg_MQ01'])
                      when v['4A1'] >= 7.3 then
                        coalesce(v['15C1_Mg'], v['15F1_Mg'], v['15A1_Mg'], v['18F1_Mg']/120, v['15C1_Mg_MQ01'])
                      else
                        coalesce(v['15A1_Mg'], v['15A2_Mg'], v['15F1_Mg'], v['15C1_Mg'], v['15D3_Mg'], v['18F1_Mg']/120, v['15A1_Mg_MQ02'], v['15C1_Mg_MQ01'])
                    end),
     v['Cat_Na'] = (case
                      when v['4A1'] < 7.3 and v['3A1'] > 0.3 then
                        coalesce(v['15A2_Na'], v['15A3_Na'], (v['15A1_Na']- (v['5A2']/354.5)), v['15A1_Na'], v['15F1_Na'], v['15C1_Na'], v['18F1_Na']/230)
                      when v['4A1'] >= 7.3 then
                        coalesce(v['15C1_Na'], v['15A1_Na'], v['15F1_Na'], v['18F1_Na']/230)
                      else
                        coalesce(v['15A1_Na'], v['15A2_Na'], v['15F1_Na'], v['15C1_Na'], v['15D3_Na'], v['18F1_Na']/230)
                    end),
     v['Cat_K'] = (case
                      when v['4A1'] < 7.3 and v['3A1'] > 0.3 then
                        coalesce(v['15A2_K'], v['15A1_K'], v['15F1_K'], v['15C1_K'], v['18F1_K']/390)
                      when v['4A1'] >= 7.3 then
                        coalesce(v['15C1_K'], v['15F1_K'], v['15A1_K'], v['18F1_K']/390)
                      else
                        coalesce(v['15A1_K'], v['15A2_K'], v['15F1_K'], v['15C1_K'], v['15D3_K'], v['18F1_K']/390)
                    end),
    m['Cat_Ca'] = (case
                      when v['4A1'] < 7.3 and v['3A1'] > 0.3 then
                        coalesce(m['15A2_Ca'], m['15A1_Ca'], m['15F1_Ca'], m['15C1_Ca'], m['18F1_Ca'], m['15A1_Ca_MQ02'], m['15C1_Ca_MQ01'])
                      when v['4A1'] >= 7.3 then
                        coalesce(m['15C1_Ca'], m['15F1_Ca'], m['15A1_Ca'], m['15C1_Ca_MQ01'])
                      else
                        coalesce(m['15A1_Ca'], m['15A2_Ca'], m['15F1_Ca'], m['15C1_Ca'], m['15D3_Ca'], m['18F1_Ca'], m['15A1_Ca_MQ02'], m['15C1_Ca_MQ01'])
                    end),
    m['Cat_Mg'] = (case
                      when v['4A1'] < 7.3 and v['3A1'] > 0.3 then
                        coalesce(m['15A2_Mg'], m['15A1_Mg'], m['15F1_Mg'], m['15C1_Mg'], m['18F1_Mg'], m['15A1_Mg_MQ02'], m['15C1_Mg_MQ01'])
                      when v['4A1'] >= 7.3 then
                        coalesce(m['15C1_Mg'], m['15F1_Mg'], m['15A1_Mg'], m['18F1_Mg'], m['15C1_Mg_MQ01'])
                      else
                        coalesce(m['15A1_Mg'], m['15A2_Mg'], m['15F1_Mg'], m['15C1_Mg'], m['15D3_Mg'], m['18F1_Mg'], m['15A1_Mg_MQ02'], m['15C1_Mg_MQ01'])
                    end),
    m['Cat_Na'] = (case
                      when v['4A1'] < 7.3 and v['3A1'] > 0.3 then
                        coalesce(m['15A2_Na'], m['15A3_Na'], m['15A1_Na'], m['15A1_Na'], m['15F1_Na'], m['15C1_Na'], m['18F1_Na'])
                      when v['4A1'] >= 7.3 then
                        coalesce(m['15C1_Na'], m['15A1_Na'], m['15F1_Na'], m['18F1_Na'])
                      else
                        coalesce(m['15A1_Na'], m['15A2_Na'], m['15F1_Na'], m['15C1_Na'], m['15D3_Na'], m['18F1_Na'])
                    end),
    m['Cat_K'] = (case
                      when v['4A1'] < 7.3 and v['3A1'] > 0.3 then
                        coalesce(m['15A2_K'], m['15A1_K'], m['15F1_K'], m['15C1_K'], m['18F1_K'])
                      when v['4A1'] >= 7.3 then
                        coalesce(m['15C1_K'], m['15F1_K'], m['15A1_K'], m['18F1_K'])
                      else
                        coalesce(m['15A1_K'], m['15A2_K'], m['15F1_K'], m['15C1_K'], m['15D3_K'], m['18F1_K'])
                    end),
    v['Cat_Acid'] = v['15G1_H'],
    m['Cat_Acid'] = m['15G1_H'],
    v['CS'] = v['2Z2_CS'],
    m['CS'] = m['2Z2_CS'],
    v['FS'] = v['2Z2_FS'],
    m['FS'] = m['2Z2_FS'],
    v['Silt'] = v['2Z2_Silt'],--MIR has been removed
    m['Silt'] = m['2Z2_Silt'],--MIR has been removed
    v['Clay'] = v['2Z2_Clay'],--MIR has been removed
    m['Clay'] = m['2Z2_Clay'],--MIR has been removed
    v['Cat_CEC'] = (case
                      when v['4A1'] < 7.3 and v['3A1'] > 0.3 then
                        coalesce(v['15B2_CEC'], v['15D2_CEC'],
                          (v['Cat_Ca']+v['Cat_Mg']+v['Cat_K']+v['Cat_Na']+nvl(v['Cat_acid'],0)), 
                           v['15J2_MQ02'], v['15C2_CEC_MQ01'])
                      when v['4A1'] >= 7.3 then
                        coalesce(v['15C1_CEC'], 
                          (v['Cat_Ca']+v['Cat_Mg']+v['Cat_K']+v['Cat_Na']), 
                          v['15C1_CEC_MC91'], v['15C2_CEC_MQ01'])
                      else
                        coalesce(v['15B1_CEC'], v['15D1_CEC'], v['15J1'], 
                          (v['Cat_Ca']+v['Cat_Mg']+v['Cat_K']+v['Cat_Na']+nvl(v['Cat_acid'],0)), 
                           v['15C1_CEC'], v['15J2_MQ02'], v['15C2_CEC_MQ01'], v['15C1_CEC_MC91'])
                    end),
    m['Cat_CEC'] = (case
                      when v['4A1'] < 7.3 and v['3A1'] > 0.3 then
                        coalesce(m['15B2_CEC'], m['15D2_CEC'], m['Cat_Ca'], m['15J2_MQ02'], m['15C2_CEC_MQ01'])
                      when v['4A1'] >= 7.3 then
                        coalesce(m['15C1_CEC'], m['Cat_Na'], m['15C1_CEC_MC91'], m['15C2_CEC_MQ01'])
                      else
                        coalesce(m['15B1_CEC'], m['15D1_CEC'], m['15J1'], m['Cat_Na'], m['15C1_CEC'], m['15J2_MQ02'], m['15C2_CEC_MQ01'], m['15C1_CEC_MC91'])
                    end),
    v['Ca_Mg'] = (case
                  when v['Cat_CEC'] > 3 then
                  v['Cat_Ca'] / v['Cat_Mg']
                  when v['Cat_Ca'] is not null and v['Cat_Mg'] is not null then
                  null
                  end),
    m['Ca_Mg'] = (case
                  when v['Cat_CEC'] > 3 then
                  m['Cat_Ca']
                  when v['Cat_Ca'] is not null and v['Cat_Mg'] is not null then
                  'CEC too low' 
                  end),
    v['ESP'] = (case
                  when v['Cat_CEC'] > 3 then
                  v['Cat_Na'] / v['Cat_CEC'] * 100
                  when v['Cat_Na'] is not null and v['Cat_CEC'] is not null then
                  null
                  end),
    m['ESP'] = (case
                  when v['Cat_CEC'] > 3 then
                    m['Cat_CEC']
                  when v['Cat_Na'] is not null and v['Cat_CEC'] is not null then
                  'CEC too low' 
                  end),
    v['Clay_Act'] = (case
                      when v['Cat_CEC'] > 3 and v['Clay'] > 35 then
                      v['Cat_CEC'] / v['Clay']
                      when v['Cat_CEC'] is not null and v['Clay'] is not null then
                      null
                      end),
    m['Clay_Act'] = (case
                      when v['Cat_CEC'] > 3 and v['Clay'] > 35 then
                        m['Clay']
                      when v['Cat_CEC'] is not null and v['Clay'] is not null then
                        'Not clay'
                      end),
    v['WB_OC'] = coalesce(v['6A1'],(v['6B2a']*0.935)),
    m['WB_OC'] = coalesce(m['6A1'],m['6B2a']),
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
  and sn.HORIZON_NO = m.HORIZON_NO -- samples to lab results table join
  and sn.SAMPLE_NO = m.SAMPLE_NO -- samples to lab results table join
  and h.PROJECT_CODE = ss.PROJECT_CODE --horizon to structures table join
  and h.SITE_ID = ss.SITE_ID --horizon to structures table join
  and h.OBS_NO = ss.OBS_NO --horizon to structures table join
  and h.HORIZON_NO = ss.HORIZON_NO --horizon to structures table join
  --and ((ss.compound_pedality IS NULL) OR (ss.compound_pedality = 1))
  --and c.latitude between -26.476401 and -21.205394 and c.LONGITUDE between 146.557398 and 151.586142 --Fitzroy modelling area
  --and c.latitude between -28.434373 and -25.935197 and c.LONGITUDE between 151.496465 and 153.604435 --SEQ modelling area
  and h.project_code NOT LIKE 'CQC' -- data from Project CQC excluded
  and not (h.project_code LIKE 'EIM' and h.Site_ID = 6051) -- data from EIM 6051 excluded
  and not (h.project_code LIKE 'QCS' and h.Site_ID IN (20, 21, 85, 86)) -- data from QCS 20, 21, 85 and 86 excluded
  and not (h.project_code LIKE 'FSE' and h.Site_ID = 126 and sn.sample_no = 3) -- data from FSE 126 (surface bulk) excluded 
  and not (h.project_code LIKE 'ABC' and h.Site_ID = 315) -- Site ABC 315 excluded from all queries because of clay % data inconsistancecy.
  and (m.THE_VALUE IS NOT NULL and m.THE_VALUE > 0) --result must be a value and not negative which affects ESP in sample with a EC > 0.3 (ie PZ do not turn off) 
  and h.DESIGN_MASTER IS NOT NULL --only interested in results from described soil profiles
  --and sn.upper_depth > .79 --query for Mark and Mel
  and sn.lower_depth < .16 -- restrict results to top 15cm of soil
  --Set Soil Attribute --remember to adjust rounding value at top of query (Line 33/34)
  and m.lab_meth_code in ('Clay', 'CS', 'FS', 'Silt', 'WB_OC')
  --and d.disturb_type < 3 --limit query to sites with low disturbance (0,1,2)
  
  --Clay/CS/FS
  --and (m.THE_VALUE <= 100) --USE FOR CLAY and CS and FS to elliminate percentage results > 100%
  --and not (h.project_code LIKE 'BAN' and h.Site_ID = 95) -- USE FOR CLAY and CS and FS. Site BAN 95 excluded because lab data does not correlate with field description according to LF.
  --and not (h.project_code LIKE 'BAMAR' and h.site_ID = 952 and sn.sample_no = 5) -- USE FOR CLAY. Site BAMAR 952 sample 5 excluded as gypsum present in soil solution has flocculated clay =1%
  
  --ESP
  --and (m.THE_VALUE <= 100) --USE FOR ESP to elliminate ESP percentage results > 100%
  --and not (h.project_code LIKE 'ABC' and h.Site_ID = 505 and sn.sample_no = 33) -- USE FOR ESP. Site ABC 505 Sample 33 excluded because cation data incorrect.
  --and not (h.project_code LIKE 'ABC' and h.Site_ID = 505 and sn.sample_no = 36) -- USE FOR ESP. Site ABC 505 Sample 36 excluded because cation data incorrect.
  --and not (h.project_code LIKE 'ABC' and h.Site_ID = 500 and sn.sample_no = 31) -- USE FOR ESP. Site ABC 500 Sample 31 excluded because cation data incorrect.
  --and not (h.project_code LIKE 'WDH' and h.Site_ID = 9098 and sn.sample_no = 13) -- USE FOR ESP. Site WDH 9098 Sample 13 excluded because cation data incorrect.
  
  --Salinity
  and not (h.project_code LIKE 'MON' and h.Site_ID = 6094 and sn.sample_no = 4) -- USE FOR EC. Site MON 6094 Sample 4 excluded because 3A1 and 2Z2_Silt data obviously incorrect.
  and not (h.project_code LIKE 'MON' and h.Site_ID = 6089 and sn.sample_no = 3) -- USE FOR EC. Site MON 6089 Sample 3 excluded because 3A1 and 2Z2_Silt data obviously incorrect.
  and not (h.project_code LIKE 'AGOPS' and h.Site_ID = 162 and sn.sample_no = 16) -- USE FOR EC. Site AGOPS 162 Sample 16 excluded because 3A1 data obviously incorrect.
  and not (h.project_code LIKE 'EIL' and h.Site_ID = 1000) -- USE FOR EC. Site EIL 1000 excluded because 3A1 data influenced by secondary salinity.
  
  --Silt
  --and (m.THE_VALUE <= 100) --USE FOR SILT to elliminate Silt percentage results > 100%
  --and not (h.project_code LIKE 'BAN' and h.Site_ID = 95) -- USE FOR SILT. Site BAN 95 excluded because lab data does not correlate with field description according to LF.
  --and not (h.project_code LIKE 'MCL' and h.Site_ID = 9052 and sn.sample_no = 31) -- USE FOR SILT. Site MCL 9052 sample 31 excluded because of funny silt value.
  --and not (h.project_code LIKE 'BAMAR' and h.Site_ID = 952 and sn.sample_no = 5) -- USE FOR SILT. Site BAMAR 952 sample 5 excluded because of funny silt value.
  --and h.project_code NOT LIKE 'MON' -- USE FOR SILT. All MON sites excluded because numeric value is inconsistent with formatted value.
  --and not (h.project_code LIKE 'CCL' and h.site_id = 317 and sn.sample_no = 2) -- USE FOR SILT. Sample CCL 317 sample 2 excluded because of funny value.
 
 --Exch Ca
  --and not (h.project_code LIKE 'BAMAR' and h.site_ID = 952 and sn.sample_no = 5) -- USE FOR EXCH CA. Site BAMAR 952 sample number 5. As wrong method/ presence of gypsum affected results 
  --and not (h.project_code LIKE 'EIR' and h.site_ID = 9021 and sn.sample_no = 36) -- USE FOR EXCH CA. Site EIR 9021 sample number 36. As wrong method/ presence of gypsum affected results 
  --and not (h.project_code LIKE 'SALTC' and h.site_ID = 400 and sn.sample_no = 3)  -- USE FOR EXCH CA. Site SALTC 400 sample number 3. As wrong method/ presence of gypsum affected results
  --and not (h.project_code LIKE 'SALTC' and h.site_ID = 400 and sn.sample_no = 4)  -- USE FOR EXCH CA. Site SALTC 400 sample number 4. As wrong method/ presence of gypsum affected results
  --and not (h.project_code LIKE 'BDSM' and h.site_ID = 345 and sn.sample_no = 1)   -- USE FOR EXCH CA and MG. Site BDSM 345 samples number 1. As Exch Ca = 0 Exch Mg= 0.1.
  --and not (h.project_code LIKE '3MC' and h.site_ID = 9014)   -- USE FOR EXCH CA. 3MC 9014 samples number 2, 4, 7, 10, and 13 Exch Ca (15A1_Ca) much larger than ECEC (15J1). Site on tertiary plateau??? Acidic soils no carbonates. Not sure where Ca is coming from?. Results for 15J1, 15A1_K, 15A1_Mg, 15A1_Na look plausible. Might have been a decimal error with lab.
. 

--Exch Mg
  --and not (h.project_code LIKE 'BDSM' and h.site_ID = 345 and sn.sample_no = 1)   -- USE FOR EXCH CA and MG. Site BDSM 345 samples number 1. As Exch Ca = 0 Exch Mg= 0.1

--Exch Na
  --and not (h.project_code LIKE 'CQA' and h. site_ID = 1001)-- USE FOR EXCH NA. Site CQA 1001 only has results below 1.5m. Which affect the spline.
  --and not (h.project_code LIKE 'ABC' and h. site_ID = 500 and sn.sample_no = 31) -- Use for EXCH NA. Site ABC 500, sample number 31 as result is out by decimal point.
  --and not (h.project_code LIKE 'ABC' and h.Site_ID = 505 and sn.sample_no = 33) -- USE FOR EXCH NA. Site ABC 505 Sample 33 excluded because cation data incorrect.
  --and not (h.project_code LIKE 'ABC' and h.Site_ID = 505 and sn.sample_no = 36) -- USE FOR EXCH NA. Site ABC 505 Sample 36 excluded because cation data incorrect.
  --and not (h.project_code LIKE 'WDH' and h.Site_ID = 9098 and sn.sample_no = 13) -- USE FOR EXCH NA. Site WDH 9098 Sample 13 excluded because cation data incorrect.
  
 --Testing
  --and h.project_code = 'CCL' -- limit for testing code - DO NOT USE
  --and h.site_id = 140  -- limit for testing code - DO NOT USE
  
group by 
  (p.objectid||m.site_ID),
  p.objectid,
  m.project_code,
  m.site_ID,
  m.obs_no,
  m.horizon_no,
  m.sample_no,
  o.obs_date,
  (sn.upper_depth*100),
  (sn.lower_depth*100),
  m.the_value,
  c.latitude,
  c.longitude,
  c.zone,
  c.easting,
  c.northing

order by 
  m.project_code, 
  m.site_id, 
  --m.horizon_no, 
  (sn.upper_depth*100),
  (sn.lower_depth*100) 
;