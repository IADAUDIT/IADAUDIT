//
//  Tweak.h
//  SMS_dylib
//
//  Created by 梁伟 on 13-9-18.
//
//

//////ChatKit IM///////
@class CKIMMessage,CKMediaObject;

@interface CKConversation : NSObject
- (id)newMessageWithComposition:(id)arg1 addToConversation:(_Bool)arg2;
-(void)addMessage:(id)message;
-(void)sendMessage:(id)message newComposition:(BOOL)composition;
- (void)deleteMessage:(id)arg1;
- (void)removeMessage:(id)arg1;
- (id)latestMessage;
-(id)recipient;
-(id)messageWithComposition:(id)arg1 ;
@end

@interface CKConversationList : NSObject
+(id)sharedConversationList;
-(id)conversationForRecipients:(id)recipients create:(BOOL)create;
- (void)deleteConversation:(id)arg1;
-(id)conversationForExistingChatWithGroupID:(id)arg1 ;
-(id)_conversationForChat:(id)arg1;
-(id)conversationForHandles:(id)arg1 displayName:(id)arg2 joinedChatsOnly:(BOOL)arg3 create:(BOOL)arg4;
@end

@interface CKEntity : NSObject {
}
+(id)copyEntityForAddressString:(id)arg1;
-(void*)abRecord;
@end

@interface CKComposition : NSObject
- (id)initWithText:(id)arg1 subject:(id)arg2;
+ (id)compositionForMessageParts:(id)arg1;
+(id)compositionWithMediaObject:(id)arg1 subject:(id)arg2 ;
-(id)compositionByAppendingMediaObject:(id)arg1 ;
-(id)compositionByAppendingMediaObjects:(id)arg1 ;
-(id)compositionByAppendingComposition:(id)arg1 ;
@property(copy, nonatomic) NSAttributedString *subject; // @synthesize subject=_subject;
@property(copy, nonatomic) NSAttributedString *text; // @synthesize text=_text;
@end



@interface CKMediaObjectManager : NSObject{
}
+ (id)sharedInstance;
- (id)mediaObjectWithData:(id)arg1 UTIType:(id)arg2 filename:(id)arg3 transcoderUserInfo:(id)arg4;
@end

@interface IMFileManager : NSFileManager{
}
+ (id)defaultHFSFileManager;
- (id)UTITypeOfPath:(id)arg1;
@end


@interface CKMediaObjectMessagePart : NSObject{
}
- (id)initWithMediaObject:(id)arg1;
@end



@interface IMMessage : NSObject
-(id)plainBody;
-(id)sender;
-(id)subject;
-(id)time;
+ (instancetype)instantMessageWithText:(NSAttributedString *)arg1 flags:(unsigned long long)arg2;
@end

@interface IMHandle : NSObject
-(id)_formattedPhoneNumber;
-(id)initWithAccount:(id)arg1 ID:(id)arg2 alreadyCanonical:(BOOL)arg3 ;
@end

@interface CKIMMessage : NSObject
-(id)IMMessage;
@end

@interface FZMessage : NSObject
-(id)body;
-(id)sender;
-(id)subject;
-(id)handle;
-(id)fileTransferGUIDs;

@end



@interface IDSIDQueryController
+ (instancetype)sharedInstance;
- (NSDictionary *)_currentIDStatusForDestinations:(NSArray *)arg1 service:(NSString *)arg2 listenerID:(NSString *)arg3;
@end

@interface IMServiceImpl : NSObject
+ (instancetype)iMessageService;
+ (id)smsService;
@end

@class IMHandle;

@interface IMAccount : NSObject
- (IMHandle *)imHandleWithID:(NSString *)arg1 alreadyCanonical:(BOOL)arg2;
@end

@interface IMAccountController : NSObject
+ (instancetype)sharedInstance;
- (IMAccount *)__ck_defaultAccountForService:(IMServiceImpl *)arg1;
@end



@interface IMChat : NSObject
- (void)sendMessage:(IMMessage *)arg1;
@end

@interface IMChatRegistry : NSObject
+ (instancetype)sharedInstance;
- (IMChat *)chatForIMHandle:(IMHandle *)arg1;
@end


///CPDistributedMessagingCenter////
@interface CPDistributedMessagingCenter : NSObject
+ (id)centerNamed:(id)arg1;
- (void)runServerOnCurrentThread;
- (void)registerForMessageName:(id)arg1 target:(id)arg2 selector:(SEL)arg3;
- (BOOL)sendMessageName:(id)arg1 userInfo:(id)arg2;
@end


///////////SB///////////////
@interface SpringBoard
-(BOOL)launchApplicationWithIdentifier:(id)identifier suspended:(BOOL)suspended;
-(NSDictionary *)getAbsFrame:(NSString *)type userInfo:(NSDictionary *)userInfo;
-(id)performSelector:(SEL)aSelector withObject:(id)object;
-(id)instanceMethodSignatureForSelector:(SEL)aselector;
@end

///SBLockScreenViewController///
@interface SBLockScreenManager
-(void)attemptToUnlockUIFromNotification;
-(void)attemptUnlockWithPasscode:(NSString *)password;
@end
