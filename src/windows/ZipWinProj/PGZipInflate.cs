using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
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
            if (zipFile == null)
            {
                throw new Exception("StorageFile (zipFile) passed to Inflate is null");
            }
            else if (destFolder == null)
            {
                throw new Exception("StorageFolder (destFolder) passed to Inflate is null");
            }

            Stream zipStream = await zipFile.OpenStreamForReadAsync();

            using (ZipArchive zipArchive = new ZipArchive(zipStream, ZipArchiveMode.Read))
            {
                //Debug.WriteLine("Count = " + zipArchive.Entries.Count);
                foreach (ZipArchiveEntry entry in zipArchive.Entries)
                {
                    //Debug.WriteLine("Extracting {0} to {1}", entry.FullName, destFolder.Path);
                    try
                    {
                        await InflateEntryAsync(entry, destFolder);
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine("Exception: " + ex.Message);
                    }
                }
            }
        }
    }
}
