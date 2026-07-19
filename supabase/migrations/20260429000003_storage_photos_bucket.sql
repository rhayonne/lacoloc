-- Cria o bucket público 'photos' para armazenar imagens de imóveis e quartos.
-- Estrutura de caminhos: {folder}/{owner_id}/{timestamp}.{ext}
-- folder = 'immeubles' | 'chambres'

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'photos',
  'photos',
  true,
  5242880,  -- 5 MB por arquivo
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Leitura pública: qualquer pessoa pode ver as fotos.
DROP POLICY IF EXISTS "photos_public_read" ON storage.objects;
CREATE POLICY "photos_public_read" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'photos');

-- Upload: apenas usuários autenticados, somente na própria pasta.
DROP POLICY IF EXISTS "photos_auth_insert" ON storage.objects;
CREATE POLICY "photos_auth_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'photos'
    AND (storage.foldername(name))[2] = (SELECT auth.uid()::text)
  );

-- Deleção: apenas o dono do arquivo.
DROP POLICY IF EXISTS "photos_owner_delete" ON storage.objects;
CREATE POLICY "photos_owner_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'photos'
    AND (storage.foldername(name))[2] = (SELECT auth.uid()::text)
  );
