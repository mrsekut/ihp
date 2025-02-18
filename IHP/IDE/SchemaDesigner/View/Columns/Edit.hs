module IHP.IDE.SchemaDesigner.View.Columns.Edit where

import IHP.ViewPrelude
import IHP.IDE.SchemaDesigner.Types
import qualified IHP.IDE.SchemaDesigner.Compiler as Compiler
import IHP.IDE.ToolServer.Types
import IHP.IDE.SchemaDesigner.View.Layout

data EditColumnView = EditColumnView
    { statements :: [Statement]
    , tableName :: Text
    , columnId :: Int
    , column :: Column
    , enumNames :: [Text]
    }

instance View EditColumnView where
    html EditColumnView { column = column@Column { name }, .. } = [hsx|
        <div class="row no-gutters bg-white" id="schema-designer-viewer">
            {renderObjectSelector (zip [0..] statements) (Just tableName)}
            {renderColumnSelector tableName (zip [0..] columns) statements}
        </div>
        {renderModal modal}
    |]
        where
            table = findStatementByName tableName statements
            columns = maybe [] (get #columns . unsafeGetCreateTable) table
            primaryKeyColumns = maybe [] (primaryKeyColumnNames . get #primaryKeyConstraint . unsafeGetCreateTable) table

            primaryKeyCheckbox
                | [name] == primaryKeyColumns =
                    preEscapedToHtml [plain|<label class="ml-1" style="font-size: 12px">
                            <input type="checkbox" name="primaryKey" class="mr-2" checked> Primary Key
                        </label>|]
                | name `elem` primaryKeyColumns =
                    preEscapedToHtml [plain|<label class="ml-1" style="font-size: 12px">
                            <input type="checkbox" name="primaryKey" class="mr-2" checked> Primary Key
                        </label>|]
                | otherwise =
                    preEscapedToHtml [plain|<label class="ml-1" style="font-size: 12px">
                        <input type="checkbox" name="primaryKey" class="mr-2"/> Primary Key
                    </label>|]

            allowNullCheckbox = if get #notNull column
                then preEscapedToHtml [plain|<input id="allowNull" type="checkbox" name="allowNull" class="mr-2"/>|]
                else preEscapedToHtml [plain|<input id="allowNull" type="checkbox" name="allowNull" class="mr-2" checked/>|]

            isUniqueCheckbox = if get #isUnique column
                then preEscapedToHtml [plain|<input type="checkbox" name="isUnique" class="mr-2" checked/>|]
                else preEscapedToHtml [plain|<input type="checkbox" name="isUnique" class="mr-2"/>|]

            isArrayTypeCheckbox = if isArrayType (get #columnType column)
                then preEscapedToHtml [plain|<input id="isArray" type="checkbox" name="isArray" class="mr-2" checked/>|]
                else preEscapedToHtml [plain|<input id="isArray" type="checkbox" name="isArray" class="mr-2"/>|]

            isArrayType (PArray _) = True
            isArrayType _ = False

            modalContent = [hsx|
                <form method="POST" action={UpdateColumnAction}>
                    <input type="hidden" name="tableName" value={tableName}/>
                    <input type="hidden" name="columnId" value={tshow columnId}/>

                    <div class="form-group">
                        <input
                            id="nameInput"
                            name="name"
                            type="text"
                            class="form-control"
                            autofocus="autofocus"
                            value={get #name column}
                            data-table-name-singular={singularize tableName}
                            />
                    </div>

                    <div class="form-group">
                        {typeSelector (Just (get #columnType column)) enumNames}

                        <div class="mt-1 text-muted">
                            <label style="font-size: 12px">
                                {allowNullCheckbox} Nullable
                            </label>
                            <label class="ml-1" style="font-size: 12px">
                                {isUniqueCheckbox} Unique
                            </label>
                            {primaryKeyCheckbox}
                            <label class="ml-1" style="font-size: 12px">
                                {isArrayTypeCheckbox} Array Type
                            </label>
                        </div>
                    </div>

                    <div class="form-group row">
                        {defaultSelector (get #defaultValue column)}
                    </div>

                    <div class="text-right">
                        <button type="submit" class="btn btn-primary">Edit Column</button>
                    </div>
                    <input type="hidden" name="primaryKey" value={inputValue False}/>
                    <input type="hidden" name="allowNull" value={inputValue False}/>
                    <input type="hidden" name="isUnique" value={inputValue False}/>
                    <input type="hidden" name="isArray" value={inputValue False}/>
                </form>
            |]
            modalFooter = mempty
            modalCloseUrl = pathTo ShowTableAction { tableName }
            modalTitle = "Edit Column"
            modal = Modal { modalContent, modalFooter, modalCloseUrl, modalTitle }

typeSelector :: Maybe PostgresType -> [Text] -> Html
typeSelector postgresType enumNames = [hsx|
        <select id="typeSelector" name="columnType" class="form-control select2-simple">
            <optgroup label="Common Types">
                {option isSelected "TEXT" "Text"}
                {option isSelected "INT" "Int"}
                {option isSelected "UUID" "UUID"}
                {option isSelected "BOOLEAN" "Bool"}
                {option isSelected "DATE" "Date / Day"}
                {option isSelected "TIMESTAMP WITH TIME ZONE" "Timestamp (UTCTime)"}
                {option isSelected "SERIAL" "Serial"}
            </optgroup>
            {customenums enumNames}
            <optgroup label="Other Types">
                {option isSelected "TIMESTAMP WITHOUT TIME ZONE" "Timestamp (LocalTime)"}
                {option isSelected "REAL" "Float"}
                {option isSelected "DOUBLE PRECISION" "Double"}
                {option isSelected "POINT" "Point"}
                {option isSelected "BYTEA" "Binary"}
                {option isSelected "Time" "Time"}
                {option isSelected "BIGSERIAL" "Bigserial"}
                {option isSelected "SMALLINT" "Int (16bit)"}
                {option isSelected "BIGINT" "Int (64bit)"}
                {option isSelected "JSONB" "JSON"}
                {option isSelected "INET" "IP Address"}
                {option isSelected "TSVECTOR" "TSVector"}
            </optgroup>
        </select>
|]
    where
        isSelected :: Maybe Text
        isSelected = fmap Compiler.compilePostgresType postgresType

        renderEnumType enum = option isSelected enum enum
        option :: Maybe Text -> Text -> Text -> Html
        option selected value text = case selected of
            Nothing -> [hsx|<option value={value}>{text}</option>|]
            Just selection ->
                if selection == value || selection == value <> "[]"
                    then [hsx|<option value={value} selected="selected">{text}</option>|]
                    else [hsx|<option value={value}>{text}</option>|]
        customenums [] = [hsx| |]
        customenums xs = [hsx| <optgroup label="Custom Enums">
                                {forEach xs renderEnumType}
                               </optgroup>
                         |]

defaultSelector :: Maybe Expression -> Html
defaultSelector defValue = [hsx|
    <div class="col-sm-10">
        <select id="defaultSelector" name="defaultValue" class="form-control select2">
            {forEach values renderValue}
        </select>
    </div>
|]
    where
        suggestedValues = [Nothing, Just (TextExpression ""), Just (VarExpression "NULL"), Just (CallExpression "NOW" [])]
        values = if defValue `elem` suggestedValues then suggestedValues else defValue:suggestedValues

        renderValue :: Maybe Expression -> Html
        renderValue e@(Just expression) = [hsx|<option value={Compiler.compileExpression expression} selected={e == defValue}>{displayedValue}</option>|]
            where
                displayedValue = case expression of
                    TextExpression "" -> "\"\""
                    _ -> Compiler.compileExpression expression
        renderValue Nothing = [hsx|<option value="" selected={Nothing == defValue}>No default</option>|]
