//
//  HTTPMethod.swift
//  ws
//
//  Created by Haris Amin on 6/22/16.
//
//

public enum HTTPMethod: String {
    
    case GET = "GET"
    case PUT = "PUT"
    case HEAD = "HEAD"
    case POST = "POST"
    case PATCH = "PATCH"
    case DELETE = "DELETE"
    case UNDEFINED = "UNDEFINED" // it will never match
}
