// installd patch is available: https://github.com/summertriangle-dev/installd-ota-patch

%hook MIInstallableBundle

- (id)_validateBundle:(id)bundle validatingResources:(BOOL)maybe1 performingOnlineAuthorization:(BOOL)maybe2 verifyingForMigrator:(BOOL)maybe3 allowingFreeProfileValidation:(BOOL)maybe4 error:(id *)error {

return %orig(bundle, maybe1, maybe2, maybe3, YES, error);

}

%end
