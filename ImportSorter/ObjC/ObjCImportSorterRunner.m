//
//  ObjCImportSorterRunner.m
//  ImportSorter
//
//  Created by Jun Hashimoto on 2015/03/10.
//  Copyright (c) 2015年 Jun Hashimoto. All rights reserved.
//

#import "ObjCImportSorterRunner.h"
// :: Other ::
#import "ObjCClassRole.h"

@interface ObjCImportSorterRunner ()
@property (nonatomic) ObjCClassRole *classRole;
@end

@implementation ObjCImportSorterRunner

#pragma mark - public methods

static NSString *const kImportDeclarationPrefix = @"#import ";
static NSString *const kClassRoleLabelPrefix = @"// :: ";

- (instancetype)initWithTextView:(NSTextView *)textView document:(IDESourceCodeDocument *)document
{
    self = [super init];

    if (self) {
        _sourceCodeView = textView;
        _sourceCodeDocument = document;
        NSString *originalClassName = [self originalClassName];
        _classRole = [[ObjCClassRole alloc] initWithOriginalClassName:originalClassName];
    }
    return self;
}

- (void)run
{
    NSArray *importDeclarations = [self exportImportDeclarations];
    NSArray *sortedImportDeclarations = [self sortImportDeclarations:importDeclarations];

    NSMutableString *replacementString = [NSMutableString string];

    for (NSString *importDeclaration in sortedImportDeclarations) {
        [replacementString appendString:importDeclaration];
    }

    [self insertSortedImportDeclaration:replacementString];
}

#pragma mark - private methods
- (NSString *)originalClassName
{
    NSString *fileName = [_sourceCodeDocument.fileURL.absoluteString lastPathComponent];
    return [fileName stringByDeletingPathExtension];
}

- (NSArray *)exportImportDeclarations
{
    NSString *sourceString = _sourceCodeView.textStorage.string;
    NSRange range = NSMakeRange(0, sourceString.length);

    NSMutableArray *importDeclarationsArray = [NSMutableArray array];
    while (range.length > 0) {
        NSRange subRange = [sourceString lineRangeForRange:NSMakeRange(range.location, 0)];

        NSString *line = [sourceString substringWithRange:subRange];
        if ([line hasPrefix:kImportDeclarationPrefix]) {
            [importDeclarationsArray addObject:line];
        }

        range.location = NSMaxRange(subRange);
        range.length -= subRange.length;
    }

    return [importDeclarationsArray copy];
}

- (void)insertSortedImportDeclaration:(NSString *)importDeclarations
{
    NSRange replacementRange = [self getReplacementRange];
    [_sourceCodeView insertText:importDeclarations replacementRange:replacementRange];
}

- (NSRange)getReplacementRange
{
    NSInteger replaceLength = 0;
    NSInteger replaceBeginLocation = 0;
    NSInteger replaceEndLocation = 0;
    BOOL hasSetBeginLocation = NO;

    NSString *sourceString = _sourceCodeView.textStorage.string;
    NSRange range = NSMakeRange(0, sourceString.length);

    NSMutableArray *importDeclarationsArray = [NSMutableArray array];
    while (range.length > 0) {
        NSRange subRange = [sourceString lineRangeForRange:NSMakeRange(range.location, 0)];

        NSString *line = [sourceString substringWithRange:subRange];
        if ([line hasPrefix:kImportDeclarationPrefix] || [line hasPrefix:kClassRoleLabelPrefix]) {
            [importDeclarationsArray addObject:line];
            if (!hasSetBeginLocation) {
                hasSetBeginLocation = YES;
                replaceBeginLocation = subRange.location;
            }
            replaceEndLocation = subRange.location + subRange.length;
        }

        range.location = NSMaxRange(subRange);
        range.length -= subRange.length;
    }
    replaceLength = MAX(replaceEndLocation - replaceBeginLocation, 0);

    return NSMakeRange(replaceBeginLocation, replaceLength);
}

- (NSArray *)sortImportDeclarations:(NSArray *)originalImportDeclarations
{
    NSMutableArray *sortedImportDeclarations = [NSMutableArray array];

    // 各ClassRoleの#import宣言を格納するためのNSArrayを生成する
    // 各要素には、該当する#import宣言を格納するNSArrayを代入する
    NSMutableArray *importDeclarationsArray = [NSMutableArray array];
    for (int i = 0; i <= [_classRole lastImportClassRoleIndex]; i++) {
        NSMutableArray *arrayByImportRole = [NSMutableArray array];
        importDeclarationsArray[i] = arrayByImportRole;
    }

    // #import宣言をしている行毎にClassRoleを割り振り、上述のNSArrayに代入する
    for (NSString *importDeclaration in originalImportDeclarations) {
        ObjCImportClassRole importClassRole = [_classRole getImportClassRole:importDeclaration];
        NSMutableArray *arrayByImportRole = importDeclarationsArray[importClassRole];
        [arrayByImportRole addObject:importDeclaration];

        importDeclarationsArray[importClassRole] = arrayByImportRole;
    }

    // ClassRole毎のNSArrayをSortし、順番に格納する
    for (int i = 0; i <= [_classRole lastImportClassRoleIndex]; i++) {
        NSArray *importDeclarationsByImportClassRole =
            [importDeclarationsArray[i] sortedArrayUsingSelector:@selector(compare:)];

        // 該当するClassRoleに割り当てられた行が1行でもある場合は、Class Roleのラベルを付与する
        if ([importDeclarationsByImportClassRole count] != 0) {
            [sortedImportDeclarations addObject:[_classRole labelForClassRole:i]];
        }

        for (NSString *importDeclaration in importDeclarationsByImportClassRole) {
            [sortedImportDeclarations addObject:importDeclaration];
        }
    }

    return [sortedImportDeclarations copy];
}

@end
