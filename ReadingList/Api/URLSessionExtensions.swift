import Foundation
import Promises
import os.log

public extension URLSession {

    /**
     Starts and returns a Data task
    */
    @discardableResult
    func startedDataTask(with url: URL, callback: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        let task = dataTask(with: url, completionHandler: callback)
        task.resume()
        return task
    }

    func data(url: URL) -> Promise<Data> {
        return Promise<Data> { fulfill, reject in
            os_log("Requesting %{public}s", type: .info, url.absoluteString)
            self.startedDataTask(with: url) { data, _, error in
                if let error = error {
                    os_log("Data request for URL %{public}s completed with error", type: .error, url.absoluteString)
                    reject(error)
                } else if let data = data {
                    fulfill(data)
                }
            }
        }
    }
}
