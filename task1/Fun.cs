using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace task1
{
    internal class Fun
    {
        public void GenerateFiles()
        {
            Random random = new Random(); // Создаем экземпляр Random для генерации случайных чисел
            DateTime startDate = DateTime.Now.AddYears(-5); // Устанавливаем начальную дату на 5 лет назад от текущей даты
            int numberOfFiles = 100;  // Количество файлов для генерации
            int linesPerFile = 100000; // Количество строк в каждом файле
            string outputDirectory = @"F:\\dev\\task1_file"; // Указываем папку для сохранения файлов
           

            for (int fileIndex = 0; fileIndex < numberOfFiles; fileIndex++ )   // Цикл для генерации заданного количества файлов
            {
                string fileName = Path.Combine(outputDirectory,$"File_{fileIndex + 1}.txt");  // Формируем имя файла, 
                using (StreamWriter writer = new StreamWriter(fileName, false, Encoding.UTF8)) // Создаем StreamWriter для записи в файл 
                {
                    for (int lineIndex = 0; lineIndex < linesPerFile; lineIndex++)
                    {
                        string date = startDate.AddDays(random.Next(0, 365 * 5)).ToString("dd.MM.yyyy");  // Генерация случайной даты за последние 5 лет в формате dd.MM.yyyy
                        string latinText = GenerateRandomString(random, 10, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"); // Генерация случайной строки из 10  символов
                        string cyrillicText = GenerateRandomString(random, 10, "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя");  // Генерация случайной строки из 10  символов
                        int evenNumber = random.Next(1, 50000001) * 2;  // Генерация случайного положительного четного числа в диапазоне от 1 до 100 000 000
                        double floatingNumber = Math.Round(random.NextDouble() * 19 + 1, 8); // Генерация случайного положительного числа с 8 знаками после запятой в диапазоне от 1 до 20
                        string line = $"{date}||{latinText}||{cyrillicText}||{evenNumber}||{floatingNumber}||"; // Формируем строку сгенерированных данных
                        writer.WriteLine(line); // Формируем строку сгенерированных данных
                    }
                }
                Console.WriteLine($"{fileName} generated."); // Выводим сообщение о том, что файл сгенерирован
            }



        }
        // Метод для генерации случайной строки заданной длины из указанных символов
        public string GenerateRandomString(Random random, int length, string chars)
        {
            StringBuilder result = new StringBuilder(length);// Создаем StringBuilder для формирования строки
            for (int i = 0; i < length; i++)// Цикл для добавления символов в строку
            {
                result.Append(chars[random.Next(chars.Length)]); // Добавляем случайный символ из переданной строки chars
            }
            return result.ToString();  // Возвращаем сгенерированную строку
        }
        // Метод для объединения файлов в один с удалением строк, содержащих заданное сочетание символов
        public void MergeFiles(string substringToRemove)
        {
            string outputDirectory = @"F:\dev\task1_file"; // Папка с исходными файлами
            string mergedFileName = Path.Combine(outputDirectory, "MergedFile.txt"); // Имя объединенного файла

            int removedLinesCount = 0; // Счетчик удаленных строк

            using (StreamWriter writer = new StreamWriter(mergedFileName, false, Encoding.UTF8)) // Создаем StreamWriter для записи в объединенный файл
            {
                // Перебираем все файлы в указанной папке
                foreach (string filePath in Directory.GetFiles(outputDirectory, "File_*.txt"))
                {
                    using (StreamReader reader = new StreamReader(filePath, Encoding.UTF8)) // Создаем StreamReader для чтения файла
                    {
                        string line;
                        while ((line = reader.ReadLine()) != null) // Читаем файл построчно
                        {
                            if (!line.Contains(substringToRemove)) // Если строка не содержит заданное сочетание символов
                            {
                                writer.WriteLine(line); // Записываем строку в объединенный файл
                            }
                            else
                            {
                                removedLinesCount++; // Увеличиваем счетчик удаленных строк
                            }
                        }
                    }
                    Console.WriteLine($"{filePath} processed."); // Выводим сообщение о том, что файл обработан
                }
            }

            Console.WriteLine($"Merged file created: {mergedFileName}"); // Выводим сообщение о создании объединенного файла
            Console.WriteLine($"Number of removed lines containing '{substringToRemove}': {removedLinesCount}"); // Выводим количество удаленных строк
        }



    }
}
