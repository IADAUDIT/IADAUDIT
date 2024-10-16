// Hook NSURLSession's dataTaskWithRequest:completionHandler:
var NSURLSession = ObjC.classes.NSURLSession;


/*******************************************************************************
 * Config && Settings
*******************************************************************************/

// Print Function Stack Call
let isUseCache = true

// print only once stack for every function
let isPrintOnlyOnceStack = true

let cfgPrintOnceStackExceptionList = [
    "+[NSURLRequest requestWithURL:]",
]

/*******************************************************************************
 * Global Variables
*******************************************************************************/
var gPrintedStackDict = {}

var gAddrToModuleInfoDict = {}
var gModulePathToSlideDict = {}
var gModulePathToClassesDict = {}
var gModulePathAddrToSymbolDict = {}
var gClassnameToAllMethodsDict = {}
var gModulePathToSymbolsDict = {}


var free = null
var objc_getClass = null
var class_copyMethodList = null
var objc_getMetaClass = null
var method_getName = null
var dladdr = null
var _dyld_image_count = null
var _dyld_get_image_name = null
var _dyld_get_image_vmaddr_slide = null
var objc_copyClassNamesForImage = null

var filepath = null;
var outputFile = null;


// Attach to the current iOS app
if (ObjC.available) {
    // Hook the main function
    ObjC.schedule(ObjC.mainQueue, function () {
        // Import the necessary Objective-C classes
        var NSFileManager = ObjC.classes.NSFileManager;
        var NSArray = ObjC.classes.NSArray;
        var NSString = ObjC.classes.NSString;
        
        // Get the path to the Documents directory
        var paths = NSFileManager.defaultManager().URLsForDirectory_inDomains_(9, 1);
        var documentsPath = paths.objectAtIndex_(0).path();
        filepath = documentsPath +"/networkData.txt";
        console.log("Documents Path: " + documentsPath.toString());

        outputFile = new File(filepath, 'a');
    });
} else {
    console.log("Objective-C runtime is not available!");
}

function writetofile(content) {
    if (outputFile) {
        outputFile.write(content+"\n");
    }
}

/******************** iOS Common Lib Functions ********************/

function initCommonLibFunctions(){
    // console.log("Init common functions in common libs:")

    // free
    free = new NativeFunction(
        Module.findExportByName(null, 'free'),
        'void',
        ['pointer']
    )
    // console.log("free=" + free)

    objc_getClass = new NativeFunction(
        Module.findExportByName(null, 'objc_getClass'),
        'pointer',
        ['pointer']
    )
    // console.log("objc_getClass=" + objc_getClass)

    class_copyMethodList = new NativeFunction(
        Module.findExportByName(null, 'class_copyMethodList'),
        'pointer',
        ['pointer', 'pointer']
    )
    // console.log("class_copyMethodList=" + class_copyMethodList)

    objc_getMetaClass = new NativeFunction(
        Module.findExportByName(null, 'objc_getMetaClass'),
        'pointer',
        ['pointer']
    )
    // console.log("objc_getMetaClass=" + objc_getMetaClass)

    method_getName = new NativeFunction(
        Module.findExportByName(null, 'method_getName'),
        'pointer',
        ['pointer']
    )
    // console.log("method_getName=" + method_getName)

    /*
    int dladdr(const void *, Dl_info *);

    typedef struct dl_info {
                    const char      *dli_fname;     // Pathname of shared object
                    void            *dli_fbase;     // Base address of shared object
                    const char      *dli_sname;     // Name of nearest symbol
                    void            *dli_saddr;     // Address of nearest symbol
    } Dl_info;

    */
    dladdr = new NativeFunction(
        Module.findExportByName(null, 'dladdr'),
        'int',
        ['pointer','pointer']
    )
    // console.log("dladdr=" + dladdr)

    // uint32_t  _dyld_image_count(void)
    _dyld_image_count = new NativeFunction(
        Module.findExportByName(null, '_dyld_image_count'),
        'uint32',
        []
    )
    // console.log("_dyld_image_count=" + _dyld_image_count)

    // const char*  _dyld_get_image_name(uint32_t image_index) 
    _dyld_get_image_name = new NativeFunction(
        Module.findExportByName(null, '_dyld_get_image_name'),
        'pointer',
        ['uint32']
    )
    // console.log("_dyld_get_image_name=" + _dyld_get_image_name)


    // intptr_t   _dyld_get_image_vmaddr_slide(uint32_t image_index)
    _dyld_get_image_vmaddr_slide = new NativeFunction(
        Module.findExportByName(null, '_dyld_get_image_vmaddr_slide'),
        'pointer',
        ['uint32']
    )
    // console.log("_dyld_get_image_vmaddr_slide=" + _dyld_get_image_vmaddr_slide)

    // const char * objc_copyClassNamesForImage(const char *image, unsigned int *outCount)
    objc_copyClassNamesForImage = new NativeFunction(
        Module.findExportByName(null, 'objc_copyClassNamesForImage'),
        'pointer',
        ['pointer', 'pointer']
    );
    // console.log("objc_copyClassNamesForImage=" + objc_copyClassNamesForImage)
}

// https://github.com/4ch12dy/FridaLib/blob/master/iOS/iOSFridaLib.js

// xia0 log
function XLOG(log) {
    // console.log("[*] " + log)
}

// format string with width
function format(str,width){    
    str = str + ""
    var len = str.length;

    if(len > width){
            return str
    }

    for(var i = 0; i < width-len; i++){
            str += " "
    }
    return str
}

function getExecFileName(modulePath){
    modulePath += ""
    return modulePath.split("/").pop()
}

// get module info from address
function get_info_form_address(address){
    var moduleInfoDict = null
    var needAddToCache = false

    if (isUseCache){
        if (address in gAddrToModuleInfoDict){
            moduleInfoDict = gAddrToModuleInfoDict[address]
            // XLOG("Found: address=" + address + " in gAddrToModuleInfoDict, moduleInfoDict=" + toJsonStr(moduleInfoDict))
            return moduleInfoDict
        } else {
            needAddToCache = true
        }
    }

    var dl_info = Memory.alloc(Process.pointerSize*4);

    dladdr(ptr(address), dl_info)

    var dli_fname = Memory.readCString(Memory.readPointer(dl_info))
    var dli_fbase = Memory.readPointer(dl_info.add(Process.pointerSize))
    var dli_sname = Memory.readCString(Memory.readPointer(dl_info.add(Process.pointerSize*2)))
    var dli_saddr = Memory.readPointer(dl_info.add(Process.pointerSize*3))

    //XLOG("dli_fname:"+dli_fname)
    //XLOG("dli_fbase:"+dli_fbase)
    //XLOG("dli_sname:"+dli_sname)
    //XLOG("dli_saddr:"+dli_saddr)

    // var addrInfo = new Array();

    // addrInfo.push(dli_fname);
    // addrInfo.push(dli_fbase);
    // addrInfo.push(dli_sname);
    // addrInfo.push(dli_saddr);

    // //XLOG(addrInfo)
    // return addrInfo;

    moduleInfoDict = {
        "fileName": dli_fname,
        "fileAddress": dli_fbase,
        "symbolName": dli_sname,
        "symbolAddress": dli_saddr,
    }

    if (needAddToCache){
        // XLOG("Add: address=" + address + ", moduleInfoDict=" + toJsonStr(moduleInfoDict) + " into cache gAddrToModuleInfoDict")
        gAddrToModuleInfoDict[address] = moduleInfoDict
    }

    return moduleInfoDict
}

function get_image_vm_slide(modulePath){
    var moduleSlide = 0

    var needAddToCache = false

    if (isUseCache){
        if (modulePath in gModulePathToSlideDict){
            moduleSlide = gModulePathToSlideDict[modulePath]
            // XLOG("Found: modulePath=" + modulePath + " in gModulePathToSlideDict, moduleSlide=" + moduleSlide)
            return moduleSlide
        } else {
            needAddToCache = true
        }
    }

    var image_count = _dyld_image_count()

    for (var i = 0; i < image_count; i++) {
            var image_name_ptr = _dyld_get_image_name(i)
            var image_silde_ptr = _dyld_get_image_vmaddr_slide(i)
            var image_name = Memory.readUtf8String(image_name_ptr)

            if (image_name == modulePath) {
                    //XLOG(Memory.readUtf8String(image_name_ptr) + " slide:"+image_silde_ptr)
                    // return image_silde_ptr
                    moduleSlide = image_silde_ptr
                    break
            }
            //XLOG(Memory.readUtf8String(image_name_ptr) + "slide:"+image_silde_ptr)
    }

    // return 0

    if (needAddToCache){
        // XLOG("Add: modulePath=" + modulePath + ", moduleSlide=" + moduleSlide + " into cache gModulePathToSlideDict")
        gModulePathToSlideDict[modulePath] = moduleSlide
    }

    return moduleSlide
}


function get_all_objc_class(modulePath){
    var classes = new Array()

    var needAddToCache = false

    if (isUseCache){
        if (modulePath in gModulePathToClassesDict){
            classes = gModulePathToClassesDict[modulePath]
            // XLOG("Found: modulePath=" + modulePath + " in gModulePathToClassesDict, classes=" + classes)
            // XLOG("Found: modulePath=" + modulePath + " in gModulePathToClassesDict, classes.length=" + classes.length)
            return classes
        } else {
            needAddToCache = true
        }
    }

    // if given modulePath nil, default is mainBundle
    if(!modulePath){
        var path = ObjC.classes.NSBundle.mainBundle().executablePath().UTF8String()
    }else{
        var path = modulePath
    }

    // create args
    var pPath = Memory.allocUtf8String(path)
    var p = Memory.alloc(Process.pointerSize)
    Memory.writeUInt(p, 0)

    var pClasses = objc_copyClassNamesForImage(pPath, p)
    var count = Memory.readUInt(p)
    classes = new Array(count)

    for (var i = 0; i < count; i++) {
            var pClassName = Memory.readPointer(pClasses.add(i * Process.pointerSize))
            classes[i] = Memory.readUtf8String(pClassName)
    }

    free(pClasses)

    if (needAddToCache){
        // XLOG("Add: modulePath=" + modulePath + ", classes=" + classes + " into cache gModulePathToClassesDict")
        // XLOG("Add: modulePath=" + modulePath + ", classes.length=" + classes.length + " into cache gModulePathToClassesDict")
        gModulePathToClassesDict[modulePath] = classes
    }

    // XLOG(classes)
    return classes
}


function get_all_class_methods(classname){
    var allMethods = new Array()

    var needAddToCache = false

    if (isUseCache){
        if (classname in gClassnameToAllMethodsDict){
            allMethods = gClassnameToAllMethodsDict[classname]
            // XLOG("Found: classname=" + classname + " in gClassnameToAllMethodsDict, allMethods=" + toJsonStr(allMethods))
            // XLOG("Found: classname=" + classname + " in gClassnameToAllMethodsDict, allMethods.length=" + allMethods.length)
            return allMethods
        } else {
            needAddToCache = true
        }
    }

    // get objclass and metaclass
    var name = Memory.allocUtf8String(classname)
    var objClass = objc_getClass(name)
    var metaClass = objc_getMetaClass(name)

    // get obj class all methods
    var size_ptr = Memory.alloc(Process.pointerSize)
    Memory.writeUInt(size_ptr, 0)
    var pObjMethods = class_copyMethodList(objClass, size_ptr)
    var count = Memory.readUInt(size_ptr)

    var allObjMethods = new Array()

    // get obj class all methods name and IMP
    for (var i = 0; i < count; i++) {
        var curObjMethod = new Array()
        var pObjMethodSEL = method_getName(pObjMethods.add(i * Process.pointerSize))
        var pObjMethodName = Memory.readCString(Memory.readPointer(pObjMethodSEL))
        var objMethodIMP = Memory.readPointer(pObjMethodSEL.add(2*Process.pointerSize))
        // XLOG("-["+classname+ " " + pObjMethodName+"]" + ":" + objMethodIMP)
        curObjMethod.push(pObjMethodName)
        curObjMethod.push(objMethodIMP)
        allObjMethods.push(curObjMethod)
    }

    var allMetaMethods = new Array()

    // get meta class all methods name and IMP
    var pMetaMethods = class_copyMethodList(metaClass, size_ptr)
    var count = Memory.readUInt(size_ptr)
    for (var i = 0; i < count; i++) {
        var curMetaMethod = new Array()

        var pMetaMethodSEL = method_getName(pMetaMethods.add(i * Process.pointerSize))
        var pMetaMethodName = Memory.readCString(Memory.readPointer(pMetaMethodSEL))
        var metaMethodIMP = Memory.readPointer(pMetaMethodSEL.add(2*Process.pointerSize))
        //XLOG("+["+classname+ " " + pMetaMethodName+"]" + ":" + metaMethodIMP)
        curMetaMethod.push(pMetaMethodName)
        curMetaMethod.push(metaMethodIMP)
        allMetaMethods.push(curMetaMethod)
    }

    allMethods.push(allObjMethods)
    allMethods.push(allMetaMethods)

    free(pObjMethods)
    free(pMetaMethods)

    if (needAddToCache){
        // XLOG("Add: classname=" + classname + ", allMethods=" + toJsonStr(allMethods) + " into cache gClassnameToAllMethodsDict")
        // XLOG("Add: classname=" + classname + ", allMethods.length=" + allMethods.length + " into cache gClassnameToAllMethodsDict")
        gClassnameToAllMethodsDict[classname] = allMethods
    }

    return allMethods
}

function find_symbol_from_address(modulePath, addr){
    var symbol = "???"
    var modulePathAddr = modulePath + "|" + addr

    var needAddToCache = false

    if (isUseCache){
        if (modulePathAddr in gModulePathAddrToSymbolDict){
            symbol = gModulePathAddrToSymbolDict[modulePathAddr]
            // XLOG("Found: modulePathAddr=" + modulePathAddr + " in gModulePathAddrToSymbolDict, symbol=" + symbol)
            return symbol
        } else {
            needAddToCache = true
        }
    }

    var frameAddr = addr
    var theDis = 0xffffffffffffffff
    var tmpDis = 0
    var theClass = "None"
    var theMethodName = "None"
    var theMethodType = "-"
    var theMethodIMP = 0

    var allClassInfo = {}

    var allClass = get_all_objc_class(modulePath)

    for(var i = 0, len = allClass.length; i < len; i++){
        var curClassName = allClass[i]
        // var mInfo = get_all_class_method(curClassName)
        var mInfo = get_all_class_methods(curClassName)

        var objms = mInfo[0]
        for(var j = 0, olen = objms.length; j < olen; j++){
            var mname = objms[j][0]
            var mIMP = objms[j][1]
            if(frameAddr >= mIMP){
                var tmpDis = frameAddr-mIMP
                if(tmpDis < theDis){
                    theDis = tmpDis
                    theClass = curClassName
                    theMethodName = mname
                    theMethodIMP = mIMP
                    theMethodType = "-"
                }
            }
        }

        var metams = mInfo[1]
        for(var k = 0, mlen = metams.length; k < mlen; k++){
            var mname = metams[k][0]
            var mIMP = metams[k][1]
            if(frameAddr >= mIMP){
                var tmpDis = frameAddr-mIMP
                if(tmpDis < theDis){
                    theDis = tmpDis
                    theClass = curClassName
                    theMethodName = mname
                    theMethodIMP = mIMP
                    theMethodType = "+"
                }
            }
        }
    }

    symbol = theMethodType+"["+theClass+" "+theMethodName+"]"

    if(symbol.indexOf(".cxx") != -1){
            symbol = "maybe C function?"
    }

    // if distance > 3000, maybe a c function
    if(theDis > 3000){
            symbol = "maybe C function? symbol:" + symbol
    }

    if (needAddToCache){
        // XLOG("Add: modulePathAddr=" + modulePathAddr + ", symbol=" + symbol + " into cache gModulePathAddrToSymbolDict")
        gModulePathAddrToSymbolDict[modulePathAddr] = symbol
    }

    return symbol
}


function generateFunctionCallStackList(context){
    var functionCallList = new Array()

    var mainPath = ObjC.classes.NSBundle.mainBundle().executablePath().UTF8String()
    // XLOG("mainPath=" + mainPath)
    var mainModuleName = getExecFileName(mainPath)
    // XLOG("mainModuleName=" + mainModuleName)

    var backtrace = Thread.backtrace(context, Backtracer.ACCURATE).map(DebugSymbol.fromAddress)
    // console.log("backtrace=" + backtrace);
    for (var i = 0;i < backtrace.length;i ++)
    {
        // curStackFrame=0x10a1d1910 SharedModules!WAGetWCIHttpImpl
        // curStackFrame=0x1070f0cb4 !0x2304cb4 (0x102304cb4)
        // curStackFrame=0x1944a9614 /System/Library/Frameworks/CFNetwork.framework/CFNetwork!+[NSURLRequest requestWithURL:]
        var curStackFrame = backtrace[i] + ''
        // XLOG("curStackFrame=" + curStackFrame)

        // var curSym = curStackFrame.split("!")[1]
        var stackFrameSplittedArr = curStackFrame.split("!")
        var curAddrAndModuleStr = stackFrameSplittedArr[0]
        // XLOG("curAddrAndModuleStr=" + curAddrAndModuleStr)
        var curSym = stackFrameSplittedArr[1]
        // XLOG("curSym=" + curSym)

        // var curAddr = curStackFrame.split("!")[0].split(" ")[0]
        var curAddrAndModuleArr = curAddrAndModuleStr.split(" ")
        // XLOG("curAddrAndModuleArr=" + curAddrAndModuleArr)
        var curAddr = curAddrAndModuleArr[0]
        // XLOG("curAddr=" + curAddr)
        // var curModuleName = curStackFrame.split("!")[0].split(" ")[1]
        var curModuleName = curAddrAndModuleArr[1]
        // XLOG("curModuleName=" + curModuleName)

        var moduleInfoDict = get_info_form_address(curAddr);
        // XLOG("moduleInfoDict=" + toJsonStr(moduleInfoDict))

        var curModulePath = moduleInfoDict["fileName"]
        // // console.log("curModulePath=" + curModulePath)
        var fileAddress = moduleInfoDict["fileAddress"]
        // // console.log("fileAddress=" + fileAddress)
        var symbolName = moduleInfoDict["symbolName"]
        // // console.log("symbolName=" + symbolName)
        var symbolAddress = moduleInfoDict["symbolAddress"]
        // // console.log("symbolAddress=" + symbolAddress)

        // skip frida call stack
        if(!curModulePath){
            XLOG("! Omit for empty module path, parsed from curAddr=" + curAddr + ", moduleInfoDict=" + moduleInfoDict)
            continue
        }

        // var fileAddr = curAddr - get_image_vm_slide(curModulePath);
        var curModuleSlide = get_image_vm_slide(curModulePath)
        // XLOG("curModuleSlide=" + curModuleSlide)
        var fileAddr = curAddr - curModuleSlide
        // XLOG("fileAddr=" + fileAddr)

        // is the image in app dir?
        if (curModulePath.indexOf(mainModuleName) != -1 ) {
            curSym = find_symbol_from_address(curModulePath, curAddr)
            if (curSym.includes("maybe C function")){
                curSym = find_symbol_from_address(curModulePath, fileAddr)
                curSym = "maybe C function? Fileaddr:" + curSym
            }
            // XLOG("new curSym=" + curSym)
        }

        var curFunctionCallDict = {
            "curModulePath": curModulePath,
            "curAddr": curAddr,
            "fileAddr": fileAddr,
            "curSym": curSym,
        }
        functionCallList.push(curFunctionCallDict)
    }

    return functionCallList
}

function generateFunctionCallStackStr(functionCallList){
    var functionCallStackStr = "------------------------ printFunctionCallStack_symbol  ------------------------"
    functionCallStackStr += "\n"
    for (var i = 0;i < functionCallList.length; i++){
        var curFunctionCallDict = functionCallList[i]
        var curModulePath = curFunctionCallDict["curModulePath"]
        var curAddr = curFunctionCallDict["curAddr"]
        var fileAddr = curFunctionCallDict["fileAddr"]
        var curSym = curFunctionCallDict["curSym"]
        var executableFilename = getExecFileName(curModulePath)
        let execMaxWidth = 20
        // let execMaxWidth = 25
        var curFuncCallStr = format(i, 4)+format(executableFilename, execMaxWidth)+"mem:"+format(ptr(curAddr),13)+"file:"+format(ptr(fileAddr),13)+format(curSym,80)
        functionCallStackStr += curFuncCallStr + "\n"
    }
    functionCallStackStr += "--------------------------------------------------------------------------------"
    return functionCallStackStr
}

function printFunctionCallStack_symbol(context){
    var functionCallStackList = generateFunctionCallStackList(context)
    var functionCallStackStr = generateFunctionCallStackStr(functionCallStackList)
    // console.log(functionCallStackStr)
    return functionCallStackStr
}

initCommonLibFunctions();

Interceptor.attach(ObjC.classes.NSURLSessionTask['- resume'].implementation, {
    onEnter: function(args) {
        this.logBuffer = [];
        var task = ObjC.Object(args[0]); 

        var originalRequest = task.originalRequest();
        var url = originalRequest.URL();
        if (url) {
            this.logBuffer.push("[*] NSURLSessionTask resume: URL -> " + url.absoluteString());
        }
        var httpMethod = originalRequest.HTTPMethod();
        // console.log("[*] HTTP Method: " + httpMethod);
        this.logBuffer.push("[*] HTTP Method: " + httpMethod);

        // Print request headers
        var allHeaders = originalRequest.allHTTPHeaderFields();
        if (allHeaders) {
            // console.log("[*] Request Headers: " + allHeaders.toString());
            this.logBuffer.push("[*] Request Headers: " + allHeaders.toString());
        }

        // Print request body if it's a POST or PUT
        var httpBody = originalRequest.HTTPBody();
        if (httpBody) {
            var bodyString = ObjC.classes.NSString.alloc().initWithData_encoding_(httpBody, 4);
            if (bodyString) {
                // console.log("[*] Request Body: " + bodyString.toString());
                this.logBuffer.push("[*] Request Body: " + bodyString.toString());
            } else {
                // console.log("[*] Request Body: (Unable to convert data to string)");
                this.logBuffer.push("[*] Request Body: (Unable to convert data to string)");
            }
        } else {
            // console.log("[*] Request Body: (No body data)");
            this.logBuffer.push("[*] Request Body: (No body data)");
        }        
        // Print the call stack
        var functionCallStackList = generateFunctionCallStackList(this.context)
        var functionCallStackStr = generateFunctionCallStackStr(functionCallStackList)
        // console.log(functionCallStackStr)
        this.logBuffer.push(functionCallStackStr)
        writetofile(this.logBuffer.join('\n'));
    }
});


// Hook dataTaskWithRequest:completionHandler:
Interceptor.attach(NSURLSession['- dataTaskWithRequest:completionHandler:'].implementation, {
    onEnter: function(args) {
        var request = new ObjC.Object(args[2]);
        this.logBuffer = [];
        // console.log("[*] NSURLSession dataTaskWithRequest: URL -> " + request.URL().absoluteString());
        this.logBuffer.push("[*] NSURLSession dataTaskWithRequest: URL -> " + request.URL().absoluteString());

        // Print the HTTP method (GET, POST, etc.)
        var httpMethod = request.HTTPMethod();
        // console.log("[*] HTTP Method: " + httpMethod);
        this.logBuffer.push("[*] HTTP Method: " + httpMethod);

        // Print request headers
        var allHeaders = request.allHTTPHeaderFields();
        if (allHeaders) {
            // console.log("[*] Request Headers: " + allHeaders.toString());
            this.logBuffer.push("[*] Request Headers: " + allHeaders.toString());
        }

        // Print request body if it's a POST or PUT
        var httpBody = request.HTTPBody();
        if (httpBody) {
            var bodyString = ObjC.classes.NSString.alloc().initWithData_encoding_(httpBody, 4);
            if (bodyString) {
                // console.log("[*] Request Body: " + bodyString.toString());
                this.logBuffer.push("[*] Request Body: " + bodyString.toString());
            } else {
                // console.log("[*] Request Body: (Unable to convert data to string)");
                this.logBuffer.push("[*] Request Body: (Unable to convert data to string)");
            }
        } else {
            // console.log("[*] Request Body: (No body data)");
            this.logBuffer.push("[*] Request Body: (No body data)");
        }        
        // Print the call stack
        var functionCallStackList = generateFunctionCallStackList(this.context)
        var functionCallStackStr = generateFunctionCallStackStr(functionCallStackList)
        // console.log(functionCallStackStr)
        this.logBuffer.push(functionCallStackStr)
    },
    onLeave: function(retval) {
        // console.log("[*] NSURLSession dataTaskWithRequest: returned\n");
        this.logBuffer.push("[*] NSURLSession dataTaskWithRequest: returned\n");
        writetofile(this.logBuffer.join('\n'));
    }
});

Interceptor.attach(NSURLSession['- dataTaskWithRequest:'].implementation, {
    onEnter: function(args) {
        this.logBuffer = [];
        var request = new ObjC.Object(args[2]);
        // console.log("[*] NSURLSession dataTaskWithRequest: URL -> " + request.URL().absoluteString());
        this.logBuffer.push("[*] NSURLSession dataTaskWithRequest: URL -> " + request.URL().absoluteString());

        // Print the HTTP method (GET, POST, etc.)
        var httpMethod = request.HTTPMethod();
        // console.log("[*] HTTP Method: " + httpMethod);
        this.logBuffer.push("[*] HTTP Method: " + httpMethod);

        // Print request headers
        var allHeaders = request.allHTTPHeaderFields();
        if (allHeaders) {
            // console.log("[*] Request Headers: " + allHeaders.toString());
            this.logBuffer.push("[*] Request Headers: " + allHeaders.toString());
        }

        // Print request body if it's a POST or PUT
        var httpBody = request.HTTPBody();
        if (httpBody) {
            var bodyString = ObjC.classes.NSString.alloc().initWithData_encoding_(httpBody, 4);
            if (bodyString) {
                // console.log("[*] Request Body: " + bodyString.toString());
                this.logBuffer.push("[*] Request Body: " + bodyString.toString());
            } else {
                // console.log("[*] Request Body: (Unable to convert data to string)");
                this.logBuffer.push("[*] Request Body: (Unable to convert data to string)");
            }
        } else {
            // console.log("[*] Request Body: (No body data)");
            this.logBuffer.push("[*] Request Body: (No body data)");
        }        
        // Print the call stack
        var functionCallStackList = generateFunctionCallStackList(this.context)
        var functionCallStackStr = generateFunctionCallStackStr(functionCallStackList)
        // console.log(functionCallStackStr)
        this.logBuffer.push(functionCallStackStr)
    },
    onLeave: function(retval) {
        // console.log("[*] NSURLSession dataTaskWithRequest: returned\n");
        this.logBuffer.push("[*] NSURLSession dataTaskWithRequest: returned\n");
        writetofile(this.logBuffer.join('\n'));
    }
});

Interceptor.attach(NSURLSession['- dataTaskWithURL:completionHandler:'].implementation, {
    onEnter: function(args) {
        this.logBuffer = [];
        var requestURL = new ObjC.Object(args[2]);
        // console.log("[*] NSURLSession dataTaskWithURL: URL -> " + requestURL.absoluteString());
        this.logBuffer.push("[*] NSURLSession dataTaskWithURL: URL -> " + requestURL.absoluteString());

        // Print the call stack
        var functionCallStackList = generateFunctionCallStackList(this.context);
        var functionCallStackStr = generateFunctionCallStackStr(functionCallStackList);
        // console.log(functionCallStackStr);
        this.logBuffer.push(functionCallStackStr);
    },
    onLeave: function(retval) {
        // console.log("[*] NSURLSession dataTaskWithURL: returned\n");
        this.logBuffer.push("[*] NSURLSession dataTaskWithURL: returned\n");
        writetofile(this.logBuffer.join('\n'));
    }
});

Interceptor.attach(NSURLSession['- dataTaskWithURL:'].implementation, {
    onEnter: function(args) {
        this.logBuffer = [];
        var requestURL = new ObjC.Object(args[2]); 
        // console.log("[*] NSURLSession dataTaskWithURL: URL -> " + requestURL.absoluteString());
        this.logBuffer.push("[*] NSURLSession dataTaskWithURL: URL -> " + requestURL.absoluteString());

        // 打印调用栈
        var functionCallStackList = generateFunctionCallStackList(this.context);
        var functionCallStackStr = generateFunctionCallStackStr(functionCallStackList);
        // console.log(functionCallStackStr);
        this.logBuffer.push(functionCallStackStr);
    },
    onLeave: function(retval) {
        // console.log("[*] NSURLSession dataTaskWithURL: returned\n");
        this.logBuffer.push("[*] NSURLSession dataTaskWithURL: returned\n");
        writetofile(this.logBuffer.join('\n'));
    }
});

Interceptor.attach(NSURLSession['- downloadTaskWithRequest:'].implementation, {
    onEnter: function(args) {
        this.logBuffer = [];
        var request = new ObjC.Object(args[2]); 
        // console.log("[*] NSURLSession downloadTaskWithRequest: URL -> " + request.URL().absoluteString());
        this.logBuffer.push("[*] NSURLSession downloadTaskWithRequest: URL -> " + request.URL().absoluteString());

        // Print the HTTP method (GET, POST, etc.)
        var httpMethod = request.HTTPMethod();
        // console.log("[*] HTTP Method: " + httpMethod);
        this.logBuffer.push("[*] HTTP Method: " + httpMethod);

        // Print request headers
        var allHeaders = request.allHTTPHeaderFields();
        if (allHeaders) {
            // console.log("[*] Request Headers: " + allHeaders.toString());
            this.logBuffer.push("[*] Request Headers: " + allHeaders.toString());
        }

        // Print the call stack
        var functionCallStackList = generateFunctionCallStackList(this.context);
        var functionCallStackStr = generateFunctionCallStackStr(functionCallStackList);
        // console.log(functionCallStackStr);
        this.logBuffer.push(functionCallStackStr);
    },
    onLeave: function(retval) {
        // console.log("[*] NSURLSession downloadTaskWithRequest: returned\n");
        this.logBuffer.push("[*] NSURLSession downloadTaskWithRequest: returned\n");
        writetofile(this.logBuffer.join('\n'));
    }
});

Interceptor.attach(NSURLSession['- downloadTaskWithURL:'].implementation, {
    onEnter: function(args) {
        this.logBuffer = [];
        var requestURL = new ObjC.Object(args[2]); 
        // console.log("[*] NSURLSession dataTaskWithURL: URL -> " + requestURL.absoluteString());
        this.logBuffer.push("[*] NSURLSession dataTaskWithURL: URL -> " + requestURL.absoluteString());

        // Print the call stack
        var functionCallStackList = generateFunctionCallStackList(this.context);
        var functionCallStackStr = generateFunctionCallStackStr(functionCallStackList);
        // console.log(functionCallStackStr);
        this.logBuffer.push(functionCallStackStr);
    },
    onLeave: function(retval) {
        // console.log("[*] NSURLSession downloadTaskWithURL: returned\n");
        this.logBuffer.push("[*] NSURLSession downloadTaskWithURL: returned\n");
        writetofile(this.logBuffer.join('\n'));
    }
});

Interceptor.attach(NSURLSession['- uploadTaskWithRequest:fromData:'].implementation, {
    onEnter: function(args) {
        this.logBuffer = [];
        var request = new ObjC.Object(args[2]);  
        // console.log("[*] NSURLSession uploadTaskWithRequest:fromData: URL -> " + request.URL().absoluteString());
        this.logBuffer.push("[*] NSURLSession uploadTaskWithRequest:fromData: URL -> " + request.URL().absoluteString());

        // Print the HTTP method (GET, POST, etc.)
        var httpMethod = request.HTTPMethod();
        // console.log("[*] HTTP Method: " + httpMethod);
        this.logBuffer.push("[*] HTTP Method: " + httpMethod);

        // Print request headers
        var allHeaders = request.allHTTPHeaderFields();
        if (allHeaders) {
            // console.log("[*] Request Headers: " + allHeaders.toString());
            this.logBuffer.push("[*] Request Headers: " + allHeaders.toString());
        }

        // Handle upload data (NSData)
        var uploadData = new ObjC.Object(args[2]);  // args[2] is the NSData for the upload
        // console.log("[*] Upload Data Length -> " + uploadData.length());
        this.logBuffer.push("[*] Upload Data Length -> " + uploadData.length());

        // Print the call stack
        var functionCallStackList = generateFunctionCallStackList(this.context);
        var functionCallStackStr = generateFunctionCallStackStr(functionCallStackList);
        // console.log(functionCallStackStr);
        this.logBuffer.push(functionCallStackStr);
    },
    onLeave: function(retval) {
        // console.log("[*] NSURLSession uploadTaskWithRequest:fromData: returned\n");
        this.logBuffer.push("[*] NSURLSession uploadTaskWithRequest:fromData: returned\n");
        writetofile(this.logBuffer.join('\n'));
    }
});

Interceptor.attach(NSURLSession['- uploadTaskWithRequest:fromFile:'].implementation, {
    onEnter: function(args) {
        this.logBuffer = [];
        var request = new ObjC.Object(args[2]);  // args[1] is the NSURLRequest
        // console.log("[*] NSURLSession uploadTaskWithRequest:fromFile: URL -> " + request.URL().absoluteString());
        this.logBuffer.push("[*] NSURLSession uploadTaskWithRequest:fromFile: URL -> " + request.URL().absoluteString());

        // Print the HTTP method (GET, POST, etc.)
        var httpMethod = request.HTTPMethod();
        // console.log("[*] HTTP Method: " + httpMethod);
        this.logBuffer.push("[*] HTTP Method: " + httpMethod);

        // Print request headers
        var allHeaders = request.allHTTPHeaderFields();
        if (allHeaders) {
            // console.log("[*] Request Headers: " + allHeaders.toString());
            this.logBuffer.push("[*] Request Headers: " + allHeaders.toString());
        }

        // Handle upload file (NSURL)
        var fileURL = new ObjC.Object(args[2]);  // args[2] is the file URL (NSURL)
        // console.log("[*] File to Upload -> " + fileURL.absoluteString());
        this.logBuffer.push("[*] File to Upload -> " + fileURL.absoluteString());

        // Print the call stack
        var functionCallStackList = generateFunctionCallStackList(this.context);
        var functionCallStackStr = generateFunctionCallStackStr(functionCallStackList);
        // console.log(functionCallStackStr);
        this.logBuffer.push(functionCallStackStr);
    },
    onLeave: function(retval) {
        // console.log("[*] NSURLSession uploadTaskWithRequest:fromFile: returned\n");
        this.logBuffer.push("[*] NSURLSession uploadTaskWithRequest:fromFile: returned\n");
        writetofile(this.logBuffer.join('\n'));
    }
});

setTimeout(() => {
    outputFile.close();
    //console.log('File closed after 2 minutes.');
    
    Process.kill(Process.id);
}, 1200000);
