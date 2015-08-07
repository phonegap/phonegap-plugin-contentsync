using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Windows.Foundation;
using Windows.Storage;
using Windows.Storage.Streams;

namespace ZipWinProj
{
    public sealed class PGZipInflate
    {
        public static IAsyncAction InflateAsync(StorageFile zipSourceFile, StorageFolder destFolder)
        {
            return Inflate(zipSourceFile, destFolder).AsAsyncAction();
        }

        private static async Task InflateEntryAsync(ZipArchiveEntry entry, StorageFolder destFolder)
        {
            string filePath = entry.Name;

            if (!string.IsNullOrEmpty(filePath) && filePath.Contains("/"))
            {
                // Create sub folder 
                string subFolderName = Path.GetDirectoryName(filePath);

                StorageFolder subFolder;

                // Create or return the sub folder. 
                subFolder = await destFolder.CreateFolderAsync(subFolderName, CreationCollisionOption.OpenIfExists);

                string newFilePath = Path.GetFileName(filePath);

                if (!string.IsNullOrEmpty(newFilePath))
                {
                    // Unzip file iteratively. 
                    await InflateEntryAsync(entry, subFolder);
                }
            }
            else
            {
                // Read uncompressed contents 
                using (Stream entryStream = entry.Open())
                {
                    byte[] buffer = new byte[entry.Length];
                    entryStream.Read(buffer, 0, buffer.Length);

                    // Create a file to store the contents 
                    StorageFile uncompressedFile = await destFolder.CreateFileAsync(entry.Name, CreationCollisionOption.ReplaceExisting);

                    // Store the contents 
                    using (IRandomAccessStream uncompressedFileStream =
                    await uncompressedFile.OpenAsync(FileAccessMode.ReadWrite))
                    {
                        using (Stream outstream = uncompressedFileStream.AsStreamForWrite())
                        {
                            outstream.Write(buffer, 0, buffer.Length);
                            outstream.Flush();
                        }
                    }
                }
            }
        }
        

        private static async Task Inflate(StorageFile zipFile, StorageFolder destFolder)
        {
            Stream zipStream = await zipFile.OpenStreamForReadAsync();

            using (ZipArchive zipArchive = new ZipArchive(zipStream, ZipArchiveMode.Read))
            {
                foreach (ZipArchiveEntry entry in zipArchive.Entries)
                {
                    await InflateEntryAsync(entry, destFolder);
                }
            }     
        }
    }
}
