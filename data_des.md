# 数据情况记录
这个文档用于记录虚拟机的数据情况，用于debug

## 数据地址
首先是之前的full_data，这里包含了大部分的企业信息数据。G:\Kuangyu_Temp\Outsource\full_data.dta

清洗后的产品数据
G:\Kuangyu_Temp\Outsource\bianma.dta

其次是本次找出的发票层面的数据，位置在G:\Kuangyu_Temp\Outsource\productivity。文件夹内所有的csv文件都是本次需要用到的。
和之前对于数据的描述有区别。由于数据量过于庞大，如果直接导出数据，数量应该在10亿左右，python无法支撑，所以目前的操作方法是先在sql中进行了合并，然后再输出到csv，所以导致列名和原数据是由区别的。我目前分成这4类
1. 购方企业数据：文件后缀是firm_buy.csv。这里是按照购方企业id来加总的企业采购数据。主要列名有：购方企业id，项目代码，金额合计，数量合计。其中，购方企业id对应full_data中的firm_id,项目代码是product_id，金额合计是统计得到的总交易额，数量合计是交易数量。因此我们想得到单价，用这金额除以数量就可以了
2. 销方企业数据：文件后缀是firm_sell.csv。同样，这里是按照销方企业id来加总的企业销售数据。要列名有：销方企业id，项目代码，金额合计，数量合计。各列数据和上述雷同，不再赘述
3. 购方地区数据：文件后缀是city_buy.csv。这里是按照购方企业id和购方地区来加总的企业采购数据。主要列名有：购方地区，项目代码，金额合计，数量合计。其中，购方地区是四位地区代码，用来衡量一个地区的market condition
4. 销方地区数据：文件后缀是city_sell.csv。这里是按照销方企业id和购方地区来加总的企业采购数据。主要列名有：销方地区，项目代码，金额合计，数量合计。其中，销方地区是四位地区代码，用来衡量一个地区的market condition
请注意，四个数据表中的企业id，地区代码，项目代码应该都是用字符串进行储存的。

## SQL代码
```sql
SELECT [购方企业ID], 项目代码, 
SUM(开票金额) AS 金额合计, 
SUM(TRY_CAST(数量 AS float)) AS 数量合计 
FROM ( 
SELECT [购方企业ID],项目代码,开票金额,数量 FROM dbo.GX1701 
UNION ALL SELECT [购方企业ID],项目代码,开票金额,数量 FROM dbo.GX1702 
UNION ALL SELECT [购方企业ID],项目代码,开票金额,数量 FROM dbo.GX1703
 ) a 
 
WHERE EXISTS (SELECT 1 FROM dbo.tmp_sample_cid s WHERE s.cid = a.[购方企业ID]) 
GROUP BY [购方企业ID], 项目代码;
```

```sql
SELECT [购方地区], 项目代码, 
SUM(开票金额) AS 金额合计, 
SUM(TRY_CAST(数量 AS float)) AS 数量合计 
FROM ( 
SELECT [购方企业ID], [购方地区],项目代码,开票金额,数量 FROM dbo.GX1701 
UNION ALL SELECT [购方企业ID], [购方地区],项目代码,开票金额,数量 FROM dbo.GX1702 
UNION ALL SELECT [购方企业ID], [购方地区],项目代码,开票金额,数量 FROM dbo.GX1703
 ) a 
 
WHERE EXISTS (SELECT 1 FROM dbo.tmp_sample_cid s WHERE s.cid = a.[购方企业ID]) 
GROUP BY [购方地区], 项目代码;
```
