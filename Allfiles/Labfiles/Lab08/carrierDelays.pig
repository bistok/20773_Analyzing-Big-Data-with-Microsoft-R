%declare loginName 'sshuser' 
carriers = LOAD '/user/RevoShare/$loginName/carriers.csv' USING PigStorage(',')
AS (code:chararray, description:chararray);
delayData = LOAD '/user/RevoShare/$loginName/FlightDelayDataSample.csv' USING PigStorage(',')
AS (Origin:chararray, Year:int, Month:int, 
    DayofMonth:int, DayOfWeek:int, DepTime:chararray, CRSDepTime:chararray,
    ArrTime:chararray, CRSArrTime:chararray, UniqueCarrier:chararray,
    ActualElapedTime:int, CRSElapsedTime:int, AirTime:int, ArrDelay:int,
    DepDelay:int, Dest:chararray, Distance:int, TaxiIn:int, TaxiOut:int,
    Cancelled:int, Diverted:int, CarrierDelay:int, WeatherDelay:int,
    NASDelay:int, SecurityDelay:int, LateAircraftDelay:int, Delay:int,
    MonthName:chararray, OriginState:chararray, DestState:chararray,
    OriginTimeZone: chararray);
carrierDelays = FILTER delayData BY LateAircraftDelay > 0 OR CarrierDelay > 0;
joinedData = JOIN carriers BY code, carrierDelays BY UniqueCarrier;
outputData = FOREACH joinedData GENERATE Origin, Dest, UniqueCarrier, description, CarrierDelay, LateAircraftDelay;
DUMP outputData;
STORE outputData INTO '/user/RevoShare/$loginName/results' USING PigStorage(',');
