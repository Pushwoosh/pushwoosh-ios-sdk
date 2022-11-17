//
//  WKUserScript+InterfacesScriptGenerator.m
//  EasyJSWKWebView
//
//  Created by Zayin Krige on 2016/10/05.
//  Copyright © 2016 Apex Technology. All rights reserved.
//

#import "WKUserScript+PWInterfacesScriptGenerator.h"
#import <objc/runtime.h>
#import "PWEasyJSWKWebView.h"

@implementation WKUserScript (PWInterfacesScriptGenerator)

+ (instancetype)pw_generateScriptForInterfaces:(NSDictionary *)interfaces {
    NSMutableString* injection = [NSMutableString new];
    
    //inject the javascript interface
    for(NSString *key in [interfaces allKeys]) {
        NSObject* interface = [interfaces objectForKey:key];
        
        [injection appendString:@"EasyJS.inject(\""];
        [injection appendString:key];
        [injection appendString:@"\", ["];
        
        unsigned int mc = 0;
        Class cls = object_getClass(interface);
        Method * mlist = class_copyMethodList(cls, &mc);
        for (int i = 0; i < mc; i++){
            [injection appendString:@"\""];
            [injection appendString:[NSString stringWithUTF8String:sel_getName(method_getName(mlist[i]))]];
            [injection appendString:@"\""];
            
            if (i != mc - 1){
                [injection appendString:@", "];
            }
        }
        
        free(mlist);
        
        [injection appendString:@"]);"];
    }
    
    WKUserScript *script = [[WKUserScript alloc] initWithSource:injection injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    return script;
}

+ (instancetype)pw_generateMainScript {
     NSString *content =
    @"\
    window.EasyJS = {\n\
    __callbacks: {},\n\
    \n\
    invokeCallback: function (cbID, removeAfterExecute){\n\
        var args = Array.prototype.slice.call(arguments);\n\
        args.shift();\n\
        args.shift();\n\
        \n\
        for (var i = 0, l = args.length; i < l; i++){\n\
            args[i] = decodeURIComponent(args[i]);\n\
            \n\
            if (args[i] == 'true') {\n\
                args[i] = true;\n\
            } else if (args[i] == 'false') {\n\
                args[i] = false;\n\
            }\n\
        }\n\
        \n\
        var cb = EasyJS.__callbacks[cbID];\n\
        if (removeAfterExecute){\n\
            EasyJS.__callbacks[cbID] = undefined;\n\
        }\n\
        return cb.apply(null, args);\n\
    },\n\
        \n\
    call: function (obj, functionName, args){\n\
        var formattedArgs = [];\n\
        for (var i = 0, l = args.length; i < l; i++){\n\
            if (typeof args[i] == \"function\"){\n\
                formattedArgs.push(\"f\");\n\
                var cbID = \"__cb\" + (Object.keys(EasyJS.__callbacks).length);\n\
                EasyJS.__callbacks[cbID] = args[i];\n\
                formattedArgs.push(cbID);\n\
            }else{\n\
                formattedArgs.push(\"s\");\n\
                formattedArgs.push(encodeURIComponent(args[i]));\n\
            }\n\
        }\n\
        \n\
        var argStr = (formattedArgs.length > 0 ? \":\" + encodeURIComponent(formattedArgs.join(\":\")) : \"\");\n\
        \n\
        var ret = prompt(obj + \":\" + encodeURIComponent(functionName) + argStr);\n\
        \n\
        if (ret){\n\
            if (ret == 'true') {\n\
                return true;\n\
            } else if (ret == 'false') {\n\
                return false;\n\
            } else {\n\
                return decodeURIComponent(ret);\n\
            }\n\
        }\n\
    },\n\
        \n\
    inject: function (obj, methods){\n\
        window[obj] = {};\n\
        var jsObj = window[obj];\n\
        \n\
        for (var i = 0, l = methods.length; i < l; i++){\n\
            (function (){\n\
                var method = methods[i];\n\
                var jsMethod = method.replace(new RegExp(\":\", \"g\"), \"\");\n\
                jsObj[jsMethod] = function (){\n\
                    return EasyJS.call(obj, method, Array.prototype.slice.call(arguments));\n\
                };\n\
            })();\n\
        }\n\
    }\n\
    };\n\
    ";
    
    WKUserScript *script = [[WKUserScript alloc] initWithSource:content injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    
    return script;
}
@end
