#line 1 "/Users/matt/iOS/Projects/Extender-Installer/Legacy/Extender-Installer/Extender_Installer.xm"



#include <substrate.h>
#if defined(__clang__)
#if __has_feature(objc_arc)
#define _LOGOS_SELF_TYPE_NORMAL __unsafe_unretained
#define _LOGOS_SELF_TYPE_INIT __attribute__((ns_consumed))
#define _LOGOS_SELF_CONST const
#define _LOGOS_RETURN_RETAINED __attribute__((ns_returns_retained))
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif

@class MIInstallableBundle; 
static id (*_logos_orig$_ungrouped$MIInstallableBundle$_validateBundle$validatingResources$performingOnlineAuthorization$verifyingForMigrator$allowingFreeProfileValidation$error$)(_LOGOS_SELF_TYPE_NORMAL MIInstallableBundle* _LOGOS_SELF_CONST, SEL, id, BOOL, BOOL, BOOL, BOOL, id *); static id _logos_method$_ungrouped$MIInstallableBundle$_validateBundle$validatingResources$performingOnlineAuthorization$verifyingForMigrator$allowingFreeProfileValidation$error$(_LOGOS_SELF_TYPE_NORMAL MIInstallableBundle* _LOGOS_SELF_CONST, SEL, id, BOOL, BOOL, BOOL, BOOL, id *); 

#line 3 "/Users/matt/iOS/Projects/Extender-Installer/Legacy/Extender-Installer/Extender_Installer.xm"


static id _logos_method$_ungrouped$MIInstallableBundle$_validateBundle$validatingResources$performingOnlineAuthorization$verifyingForMigrator$allowingFreeProfileValidation$error$(_LOGOS_SELF_TYPE_NORMAL MIInstallableBundle* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, id bundle, BOOL maybe1, BOOL maybe2, BOOL maybe3, BOOL maybe4, id * error) {

return _logos_orig$_ungrouped$MIInstallableBundle$_validateBundle$validatingResources$performingOnlineAuthorization$verifyingForMigrator$allowingFreeProfileValidation$error$(self, _cmd, bundle, maybe1, maybe2, maybe3, YES, error);

}


static __attribute__((constructor)) void _logosLocalInit() {
{Class _logos_class$_ungrouped$MIInstallableBundle = objc_getClass("MIInstallableBundle"); MSHookMessageEx(_logos_class$_ungrouped$MIInstallableBundle, @selector(_validateBundle:validatingResources:performingOnlineAuthorization:verifyingForMigrator:allowingFreeProfileValidation:error:), (IMP)&_logos_method$_ungrouped$MIInstallableBundle$_validateBundle$validatingResources$performingOnlineAuthorization$verifyingForMigrator$allowingFreeProfileValidation$error$, (IMP*)&_logos_orig$_ungrouped$MIInstallableBundle$_validateBundle$validatingResources$performingOnlineAuthorization$verifyingForMigrator$allowingFreeProfileValidation$error$);} }
#line 12 "/Users/matt/iOS/Projects/Extender-Installer/Legacy/Extender-Installer/Extender_Installer.xm"
