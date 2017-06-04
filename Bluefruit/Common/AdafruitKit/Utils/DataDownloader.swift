//
//  DataDownloader.swift
//  Bluefruit
//
//  Created by Antonio on 27/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation

func downloadData(from url: URL, completion:@escaping ((Data?) -> Void)) {
    if url.scheme == "file" {       // Check if url is local and just open the file
        let data = try? Data(contentsOf: url)
        completion(data)
    } else {                          // If the url is not local, download the file
        let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
        let task = session.dataTask(with: url, completionHandler: { (data, response, error) in
            guard error == nil else {
                // If any error occurs then just display its description on the console.
                DLog("Error: \(error.debugDescription)")
                completion(nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DLog("Download file HTTP error")
                completion(nil)
                return

            }

            let statusCode = httpResponse.statusCode
            guard statusCode == 200 else {
                DLog("Download file HTTP status code = \(statusCode)")
                completion(nil)
                return
            }

            // Call the completion handler with the returned data on the main thread
            DispatchQueue.main.async {
                completion(data)
            }
        })

        task.resume()
    }

}
