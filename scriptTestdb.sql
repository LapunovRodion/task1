USE [testdb]
GO
/****** Object:  Table [dbo].[ImportTable1]    Script Date: 15.10.2024 0:35:39 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ImportTable1](
	[DateField] [date] NULL,
	[Field1] [nvarchar](50) NULL,
	[Field2] [nvarchar](50) NULL,
	[Field3] [bigint] NULL,
	[Field4] [varchar](50) NULL
) ON [PRIMARY]
GO
/****** Object:  StoredProcedure [dbo].[CalculateSumAndMedian]    Script Date: 15.10.2024 0:35:39 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CalculateSumAndMedian]
AS
BEGIN
    BEGIN TRY
        -- Объявление переменной для хранения суммы Field3
        DECLARE @SumInt BIGINT;

        -- Подсчет суммы значений в поле Field3 таблицы ImportTable1
        -- Используется CAST для преобразования Field3 в BIGINT
        -- WHERE ISNUMERIC(Field3) = 1 - фильтрация только числовых значений
        SELECT @SumInt = SUM(CAST(Field3 AS BIGINT))
        FROM [dbo].[ImportTable1]
        WHERE ISNUMERIC(Field3) = 1;

        -- Печать результата суммы
        PRINT 'Сумма: ' + CAST(@SumInt AS VARCHAR(50));

        -- Объявление переменной для хранения медианы Field4
        DECLARE @Median DECIMAL(18, 6);

        -- Получения отсортированных значений из Field4
        ;WITH OrderedValues AS
        (
            -- Выбор значений из Field4 и их сортировка
            SELECT
                CAST(Field4 AS DECIMAL(18, 6)) AS DecimalValue, -- Преобразование Field4 в тип DECIMAL
                ROW_NUMBER() OVER (ORDER BY CAST(Field4 AS DECIMAL(18, 6))) AS RowAsc, -- Нумерация строк по возрастанию
                COUNT(*) OVER () AS TotalRows -- Общее количество строк
            FROM [dbo].[ImportTable1]
            WHERE ISNUMERIC(Field4) = 1 
        )
        -- Вычисление медианы на основе количества строк
        SELECT @Median =
            CASE
                -- Если общее количество строк нечетное, выбирается значение из середины
                WHEN TotalRows % 2 = 1 THEN
                    (SELECT DecimalValue
                     FROM OrderedValues
                     WHERE RowAsc = (TotalRows + 1) / 2)
                -- Если четное, то медиана - это среднее арифметическое двух средних значений
                ELSE
                    (SELECT AVG(DecimalValue * 1.0)
                     FROM OrderedValues
                     WHERE RowAsc IN (TotalRows / 2, (TotalRows / 2) + 1))
            END
        FROM OrderedValues;

        -- Печать результата медианы
        PRINT 'Медиана: ' + CAST(@Median AS VARCHAR(50));
    END TRY
    BEGIN CATCH
        -- Обработка ошибок и печать сообщения об ошибке
        PRINT 'Ошибка: ' + ERROR_MESSAGE();
    END CATCH
END

GO
/****** Object:  StoredProcedure [dbo].[ImportFilesFromFolder]    Script Date: 15.10.2024 0:35:39 ******/
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
