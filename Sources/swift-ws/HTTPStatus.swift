//
//  HTTPStatus.swift
//  ws
//
//  Created by Haris Amin on 6/22/16.
//
//

public enum HTTPStatus: Int {
    
    case OK = 200
    case Created = 201
    case Accepted = 202
    
    case MultipleChoices = 300
    case MovedPermanently = 301
    case Found = 302
    case SeeOther = 303
    
    case BadRequest = 400
    case Unauthorized = 401
    case Forbidden = 403
    case NotFound = 404
    
    case InternalServerError = 500
    case BadGateway = 502
    case ServiceUnavailable = 503
    
    func statusLine() -> String {
        switch self {
        case .OK: return "OK"
        case .Created: return "Created"
        case .Accepted: return "Accepted"
            
        case .MultipleChoices: return "Multiple Choices"
        case .MovedPermanently: return "Moved Permentantly"
        case .Found: return "Found"
        case .SeeOther: return "See Other"
            
        case .BadRequest: return "Bad Request"
        case .Unauthorized: return "Unauthorized"
        case .Forbidden: return "Forbidden"
        case .NotFound: return "Not Found"
            
        case .InternalServerError: return "Internal Server Error"
        case .BadGateway: return "Bad Gateway"
        case .ServiceUnavailable: return "Service Unavailable"
        }
    }
}
