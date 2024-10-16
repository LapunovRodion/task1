USE [testdb]
GO
/****** Object:  Table [dbo].[ImportTable1]    Script Date: 15.10.2024 3:45:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ImportTable1](
	[RecordDate] [date] NULL,
	[Field1] [nvarchar](50) NULL,
	[Field2] [nvarchar](50) NULL,
	[Field3] [bigint] NULL,
	[Field4] [nvarchar](100) NULL
) ON [PRIMARY]
GO
/****** Object:  StoredProcedure [dbo].[CalculateSumAndMedian]    Script Date: 15.10.2024 3:45:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CalculateSumAndMedian]
AS
BEGIN
    SET NOCOUNT ON;

    -- Считаем сумму всех целых чисел из Field3
    DECLARE @SumBigInt BIGINT;

    SELECT @SumBigInt = SUM(Field3)
    FROM ImportTable1;

    -- Считаем медиану всех дробных чисел из Field4
	-- Убираем пробелы и специальные символы из столбца Field4
    ;WITH CleanedData AS (
        SELECT 
            REPLACE(REPLACE(LTRIM(RTRIM(Field4)), CHAR(13), ''), CHAR(10), '') AS CleanValue
        FROM ImportTable1
    ),
	-- Заменяем запятые на точки для нормализации десятичных значений
    NumericData AS (
        SELECT 
            REPLACE(CleanValue, ',', '.') AS PreparedValue
        FROM CleanedData
        WHERE PATINDEX('%[^0-9.,]%', CleanValue) = 0  -- Убираем строки, которые содержат нечисловые символы, кроме запятой и точки
    ),
	 -- Конвертируем очищенные данные в числовой тип DECIMAL
    ConvertedData AS (
        SELECT 
            TRY_CAST(PreparedValue AS DECIMAL(18, 6)) AS Value
        FROM NumericData
        WHERE TRY_CAST(PreparedValue AS DECIMAL(18, 6)) IS NOT NULL  -- Оставляем только те строки, которые корректно конвертируются
    )
	-- Находим медиану
    SELECT 
        AVG(Value) AS Median
    FROM (
        SELECT 
            Value, 
            ROW_NUMBER() OVER (ORDER BY Value) AS RowAsc,
            ROW_NUMBER() OVER (ORDER BY Value DESC) AS RowDesc,
            COUNT(*) OVER () AS TotalCount
        FROM ConvertedData
    ) AS RankedData
    WHERE RowAsc = RowDesc
       OR RowAsc + 1 = RowDesc
       OR RowDesc + 1 = RowAsc;

    -- Выводим результат
    PRINT 'Сумма всех целых чисел из Field3: ' + CAST(@SumBigInt AS VARCHAR);
END;
GO
/****** Object:  StoredProcedure [dbo].[ImportFilesFromFolder]    Script Date: 15.10.2024 3:45:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Создание процедуры для импорта файлов из папки
CREATE PROCEDURE [dbo].[ImportFilesFromFolder] (@FolderPath VARCHAR(255))
AS
BEGIN
    -- Объявление переменных
    DECLARE @FileName NVARCHAR(255); -- Переменная для хранения имени файла
    DECLARE @sqlCommand NVARCHAR(MAX); -- Переменная для хранения команды SQL
    DECLARE @cmd VARCHAR(255); -- Переменная для хранения командной строки

    DECLARE @RowCount INT; -- Переменная для хранения количества строк, импортированных из текущего файла
    DECLARE @InsertedRows INT = 0; -- Переменная для хранения общего количества вставленных строк
    DECLARE @TotalFiles INT; -- Переменная для хранения общего количества файлов
    DECLARE @ProcessedFiles INT = 0; -- Переменная для хранения количества обработанных файлов

    -- Получение списка файлов из папки
    SET @cmd = 'dir "' + @FolderPath + '\*.txt" /b';
    -- Формирование командной строки для получения списка всех файлов с расширением .txt в указанной папке

    CREATE TABLE #FileList (FileName NVARCHAR(255));
    -- Создание временной таблицы для хранения списка файлов

    INSERT INTO #FileList
    EXEC xp_cmdshell @cmd;
    -- Вставка списка файлов из командной строки в таблицу #FileList с помощью xp_cmdshell

    DELETE FROM #FileList WHERE FileName IS NULL;
    -- Удаление записей с пустыми значениями, если такие имеются

    -- Получение общего количества файлов в таблице
    SELECT @TotalFiles = COUNT(*) FROM #FileList WHERE FileName IS NOT NULL;

    -- Создание курсора для обхода списка файлов
    DECLARE file_cursor CURSOR FOR
    SELECT FileName FROM #FileList WHERE FileName IS NOT NULL;

    OPEN file_cursor; -- Открытие курсора
    FETCH NEXT FROM file_cursor INTO @FileName; -- Получение первого файла из курсора

    -- Цикл для обхода всех файлов в курсоре
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Формирование команды BULK INSERT для импорта данных из текущего файла в таблицу ImportTable1
        SET @sqlCommand = '
           BULK INSERT dbo.ImportTable1
            FROM ''' + @FolderPath + '\' + @FileName + '''
            WITH (
                FIELDTERMINATOR = ''||'', -- Разделитель полей в файле
                ROWTERMINATOR = ''0x0A'', -- Символ конца строки
                FIRSTROW = 1, -- Начинать вставку с первой строки файла
                CODEPAGE = ''65001'', -- Кодировка UTF-8
                TABLOCK, -- Использование блокировки таблицы для ускорения вставки
                KEEPNULLS -- Сохранять NULL значения для пустых полей
            );';

        BEGIN TRY
            -- Попытка выполнить команду вставки
            EXEC sp_executesql @sqlCommand;

            SET @RowCount = @@ROWCOUNT; -- Получение количества строк, вставленных из текущего файла
            SET @InsertedRows = @InsertedRows + @RowCount; -- Обновление общего количества вставленных строк
            SET @ProcessedFiles = @ProcessedFiles + 1; -- Увеличение счетчика обработанных файлов

            -- Вывод информации о текущем прогрессе импорта
            PRINT 'Файл: ' + @FileName + ' - Импортировано строк: ' + CAST(@RowCount AS NVARCHAR(MAX));
            PRINT 'Всего импортировано строк: ' + CAST(@InsertedRows AS NVARCHAR(MAX));
            PRINT 'Обработано файлов: ' + CAST(@ProcessedFiles AS NVARCHAR(MAX)) + ' из ' + CAST(@TotalFiles AS NVARCHAR(MAX));
            RAISERROR ('Прогресс: %d из %d файлов обработано.', 0, 1, @ProcessedFiles, @TotalFiles) WITH NOWAIT;
        END TRY
        BEGIN CATCH
            -- Обработка ошибок, возникших при импорте файла
            PRINT 'Ошибка при импорте файла: ' + @FileName;
            PRINT ERROR_MESSAGE(); -- Вывод сообщения об ошибке
        END CATCH;

        -- Переход к следующему файлу в курсоре
        FETCH NEXT FROM file_cursor INTO @FileName;
    END

    -- Закрытие и деаллокация курсора после завершения обработки всех файлов
    CLOSE file_cursor;
    DEALLOCATE file_cursor;

    -- Удаление временной таблицы со списком файлов
    DROP TABLE #FileList;

    -- Вывод финального сообщения об общем количестве импортированных строк
    PRINT 'Импорт завершен. Всего импортировано строк: ' + CAST(@InsertedRows AS NVARCHAR(MAX));
    RAISERROR ('Импорт завершен. Всего импортировано строк: %d.', 0, 1, @InsertedRows) WITH NOWAIT;

    -- Обновление данных в таблице после импорта: удаление лишних разделителей '||' и пробелов, замена всех запятых на точки 
    UPDATE ImportTable1
    SET Field4 = RTRIM(REPLACE(Field4, '||', ''));
	UPDATE ImportTable1 
	SET Field4 = REPLACE(Field4,',','.')
END
GO
