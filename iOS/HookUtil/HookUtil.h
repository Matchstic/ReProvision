
#import <objc/runtime.h>

//
#ifdef __cplusplus
extern "C"
{
#endif
	
	void HUHookFunction(const char *lib, const char *func, void *hook, void **old);
	void HUHookMessage(const char * cls, bool meta, const char *name, IMP hook, IMP *old);	// Name means ObjC message, use '_' for ':', '__' for '_'
	
	bool HUIsAnyOneMatched(const char *any, const char *one, char separator);
	void HUHookFunctionForProcess(const char *proc, const char *lib, const char *func, void *hook, void **old);
	void HUHookMessageForProcess(const char *proc, const char * cls, bool meta, const char *name, IMP hook, IMP *old);
#ifdef __cplusplus
}
#endif

//
#define __HUHookFunction(NOUSE, ...)						HUHookFunction(__VA_ARGS__)
#define __HUHookMessage(NOUSE, ...)							HUHookMessage(__VA_ARGS__)

#define __HOOK_FUNCTION(MOD, HKFN, PROC, RET, LIB, FUNC, ...) RET $##FUNC(__VA_ARGS__);\
															RET (*_##FUNC)(__VA_ARGS__);\
															__attribute__((MOD)) void _Init_##FUNC()\
															{\
																HKFN(#PROC, #LIB, #FUNC, (void *)$##FUNC, (void **)&_##FUNC);\
															}\
															RET $##FUNC(__VA_ARGS__)

#define __HOOK_MESSAGE(MOD, HKFN, PROC, RET, CLS, MSG, META, ...)\
															RET $##CLS##_##MSG(id self, SEL sel, ##__VA_ARGS__);\
															RET (*_##CLS##_##MSG)(id self, SEL sel, ##__VA_ARGS__);\
															__attribute__((MOD)) void _Init_##CLS##_##MSG()\
															{\
																HKFN(#PROC, #CLS, META, #MSG, (IMP)$##CLS##_##MSG, (IMP *)&_##CLS##_##MSG);\
															}\
															RET $##CLS##_##MSG(id self, SEL sel, ##__VA_ARGS__)

// Manual hook, call _Init_*** to enable the hook
#define _HOOK_FUNCTION(RET, LIB, FUN, ...)					__HOOK_FUNCTION(always_inline, __HUHookFunction, , RET, LIB, FUN, ##__VA_ARGS__)
#define _HOOK_MESSAGE(RET, CLS, MSG, ...)					__HOOK_MESSAGE(always_inline, __HUHookMessage, , RET, CLS, MSG, false, ##__VA_ARGS__)
#define _HOOK_META(RET, CLS, MSG, ...)						__HOOK_MESSAGE(always_inline, __HUHookMessage, , RET, CLS, MSG, true, ##__VA_ARGS__)

// Automatic hook
#define HOOK_FUNCTION(RET, LIB, FUN, ...)					__HOOK_FUNCTION(constructor, __HUHookFunction, , RET, LIB, FUN, ##__VA_ARGS__)
#define HOOK_MESSAGE(RET, CLS, MSG, ...)					__HOOK_MESSAGE(constructor, __HUHookMessage, , RET, CLS, MSG, false, ##__VA_ARGS__)
#define HOOK_META(RET, CLS, MSG, ...)						__HOOK_MESSAGE(constructor, __HUHookMessage, , RET, CLS, MSG, true, ##__VA_ARGS__)

// Automatic hook for special process name
// Use | separator for multiple process name
#define HOOK_FUNCTION_FOR_PROCESS(PROC, RET, LIB, FUN, ...)	__HOOK_FUNCTION(constructor, HUHookFunctionForProcess, PROC, RET, LIB, FUN, ##__VA_ARGS__)
#define HOOK_MESSAGE_FOR_PROCESS(PROC, RET, CLS, MSG, ...)	__HOOK_MESSAGE(constructor, HUHookMessageForProcess, PROC, RET, CLS, MSG, false, ##__VA_ARGS__)
#define HOOK_META_FOR_PROCESS(PROC, RET, CLS, MSG, ...)		__HOOK_MESSAGE(constructor, HUHookMessageForProcess, PROC, RET, CLS, MSG, true, ##__VA_ARGS__)
